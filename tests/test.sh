#!/usr/bin/env sh

set -e
set -x

(
  cd 1
  ../../ansible-assets.rb --init
  ../../ansible-assets.rb asset_files.yml
)

(
  cd 1
  ../../ansible-assets.rb --init
  ../../ansible-assets.rb asset_directories.yml
)

