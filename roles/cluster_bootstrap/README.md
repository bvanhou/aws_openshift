# Cluster Bootstrap

This role is used to configure the cluster hosts to for OpenShift installation

## Variables

* volume_group_name: Name of volume group for cluster logical volumes
* master_logical_volumes: List of logical volumes to configure on master nodes
* infra_logical_volumes: List of logical volumes to configure on infra nodes
* app_logical_volumes: List of logical volumes to configure on app nodes
* bastion_private_ip: Private IP address of bastion host