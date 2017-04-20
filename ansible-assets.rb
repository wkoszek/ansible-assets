#!/usr/bin/env ruby
# Copyright 2017 Wojciech Adam Koszek <wojciech@koszek.com>

require 'yaml'
require 'pp'

WHERE_FILES_ARE = "files"
SECTION_FILES = "FILES"
SECTION_DIRS = "DIRECTORIES"

def main
  if ARGV.length < 1
    usage
  end

  # http://stackoverflow.com/questions/26434923/parse-command-line-arguments-in-a-ruby-script
  cfg = Hash[ ARGV.flat_map{|s| s.scan(/--?([^=\s]+)(?:=(\S+))?/) } ]

  if cfg.include?("init")
    do_init
    exit
  end

  sanity_check

  all_blocks = []
  ARGV.each do |arg|
    doing_dirs = 0
    if arg =~ /asset_dir/
      doing_dirs = 1
    end
    all_blocks << process_ansible_file(cfg, arg, doing_dirs)
  end
  puts all_blocks.to_yaml
end

def usage
  STDERR.puts "./ansible-lint.rb [--init|--interactive] yaml_file [[yaml_file2] .. ]"
  exit 64
end

def do_init
  write_if_not_exist("asset_directories.yml", template_dirs)
  write_if_not_exist("asset_files.yml", template_files)
end

def write_if_not_exist(file_name, content)
  if File.exist?(file_name)
    STDERR.puts "File '#{file_name}' exists already. Won't create!"
  else
    File.write(file_name, content)
  end
end

def sanity_check
  if !File.directory?(WHERE_FILES_ARE)
    STDERR.puts "No directory '#{WHERE_FILES_ARE}' with files to sync."
    STDERR.puts "  Make it and assume it's yours remote server '/'"
    STDERR.puts "  Add your files in files/etc/..., files/var/... etc. and retry"
    exit
  end
end

def process_ansible_file(cfg, filename, doing_dirs=0)
  d = File.read(filename)
  y = YAML.load(d)

  if doing_dirs != 0
    section = SECTION_DIRS
    local_dir_names = list_local_dirs(WHERE_FILES_ARE)
  else
    section = SECTION_FILES
    local_dir_names = list_local_files(WHERE_FILES_ARE)
  end
  ansible_dirs_block = ansible_block_by_name(y, section)
  ansible_dir_names = ansible_dirs_block["with_items"].collect {|d| d["fn"] }

  dirs_not_yet = local_dir_names - ansible_dir_names

  files_to_add = []
  dirs_not_yet.each do |d|
    files_to_add << {
      "fn" => d,
      "owner" => ask_msg_default(cfg, "#{d} owner is?", "root"),
      "group" => ask_msg_default(cfg, "#{d} group is?", "root"),
      "mode" => ask_msg_default(cfg, "#{d} mode is?", "0655")
    }
  end

  ansible_dirs_block["with_items"] += files_to_add

  return ansible_dirs_block
end

def ask_msg_default(cfg, msg, default)
  STDERR.puts "#{msg} [default: #{default}] "
  val = ""
  if cfg.include?("interactive")
    val = STDIN.gets.strip
  end
  if val.length <= 0
    val = default
  end
  val
end

def ansible_block_by_name(ansible_yaml, name)
  ansible_yaml.select {|block|
    block["name"] == name
  }[0]
end

def list_local_files(files_dir)
  Dir.glob("#{files_dir}/**/*").collect { |fn|
    fn.gsub(/^#{WHERE_FILES_ARE}/, "")
  }
end

def list_local_dirs(files_dir)
  list_local_files(files_dir).select { |fn|
    fn if File.directory?("#{WHERE_FILES_ARE}/#{fn}")
  }
end

def template_files
  return <<EOF
- name: FILES
  copy:
    src: "files{{ item.fn }}"
    dest: "{{ item.fn }}"
    owner: "{{ item.owner }}"
    group: "{{ item.group }}"
    mode: "{{ item.mode }}"
  with_items:
  - fn: "/etc/hosts"
    owner: root
    group: root
    mode: "0644"
EOF
end

def template_dirs
  return <<EOF
- name: DIRECTORIES
  file:
    src: "files{{ item.fn }}"
    dest: "{{ item.fn }}"
    owner: "{{ item.owner }}"
    group: "{{ item.group }}"
    mode: "{{ item.mode }}"
    state: directory
  with_items:
  - { fn: "/", owner: "root", group: "root", mode: "0755" }
EOF
end

main
