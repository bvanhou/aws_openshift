# SSH Config

This role is used to configure the Ansible installer workstation's SSH configuration to access cluster resources in AWS

## Variables

* bastion_ips: List of IP addresses for bastion hosts
* master_ips: List of IP addresses for master hosts
* infra_ips: List of IP addresses for infra hosts
* app_ips: List of IP addresses for app hosts
* cluster_id: Unique cluster label (dev, prod, mine, etc). Must be unique per AZ, contain no special characters, and have 8 char max
* user_local_path: User-scoped path for files used during cluster administration
* publicly_accessible: Boolean for Whether or not the nodes have public ip addresses