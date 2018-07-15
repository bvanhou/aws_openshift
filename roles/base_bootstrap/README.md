# Base Bootstrap

This role applies a basic node configuration to a host

## Variables

* yum_repos: List of yum repos to configure
* install_packages: List of packages to install
* remove_packages: List of packages to remove
* started_enabled_services: List of systemd services to start/enable