# File permission management with Ansible

Ansible-assets helps you create necessary files and directories on a remote
server in a secure way with Ansible. It looks at files and directories which
you intend to copy to the server, and makes sure you specify correct
permission for each file.

Ansible-assets is opinionated. It assumes you have a `files/` directory,
whose hierarchy mimics `/` of the remote. So `files/etc/hosts` reflects
`/etc/hosts` on remote.

If you add a file to `files/`, ansible-assets will attempt to update
the playbook with it.
