# AWS OpenShift Deployment Automation

This repository contains playbooks used to automatically deploy and configure OpenShift clusters into AWS

* [AWS OpenShift Deployment Automation](#aws-openshift-deployment-automation)
* [Before Installation](#before-installation)
  * [General Prerequisites](#general-prerequisites)
  * [AWS Prerequisites](#aws-prerequisites)
  * [Unique cluster designation](#unique-cluster-designation)
  * [Prep ansible host and configure awscli](#prep-ansible-host-and-configure-awscli)
  * [Create AWS network load balancers](#create-aws-network-load-balancers)
  * [Create DNS entries](#create-dns-entries)
* [Deploying a cluster](#deploying-a-cluster)
  * [Using the deploy CLI tool](#using-the-deploy-cli-tool)
  * [Configure cluster template](#configure-cluster-template)
  * [Generate cluster configuration](#generate-cluster-configuration)
  * [Install OpenShift cluster](#install-openshift-cluster)
* [Post-installation administration](#post-installation-administration)
  * [Post-installation validation](#post-installation-validation)
  * [Scaling capacity](#scaling-capacity)
  * [Tearing down a cluster](#tearing-down-a-cluster)
* [Miscellaneous](#miscellaneous)
  * [Generating an AMI](#generating-an-ami)
  * [Printing cluster information](#printing-cluster-information)
  * [Common commands](#common-commands)
     * [Listing nodes](#listing-nodes)
     * [Working with AMI's](#working-with-amis)
     * [SSH to cluster nodes](#ssh-to-cluster-nodes)
  * [Using Ansible callback plugins](#using-ansible-callback-plugins)

# Before Installation

## General Prerequisites

* Workstation with the following installed
    * ansible
    * python-boto
    * python-boto3
    * python-botocore
    * AWS CLI tool
* Satellite/Yum repository with appropriate rpm packages 
* Certificates for all corporate resources the cluster hosts need to access in /etc/pki/ca-trust/source/anchors or ~/etc/ansible/certificates

## AWS Prerequisites

* Appropriate AWS resource limits set
* AWS IAM user for installation
* AWS IAM user for dynamic storage provisioning
* Private VPC with connectivity to on-premise environment
* Private Subnet
* Access to AWS API Servers with proxy if needed

## Unique cluster designation

This architecture assumes each OpenShift cluster and its infrastructure can be uniquely determined with the combination of environment and cluster number (i.e. sandbox01).
When following the steps below to generate a cluster configuration, ensure that a unique cluster environment/number has been established before continuing. Using an id for a new cluster that is in use could have very undesirable consequences.

## Prep ansible host and configure awscli

Before running these playbooks the host ansible will be running from must have the expected dependencies installed and be properly configured to communicate with AWS via the [awscli](https://aws.amazon.com/cli/)

```shell
# Install prerequisites
[user@workstation aws_devops]$ sudo yum -y install ansible python-boto python-boto3 python-botocore pyyaml bind-utils

# Install aws command and API support
[user@workstation aws_devops]$ ./scripts/aws-setup.sh

# Reload Bash profile
[user@workstation aws_devops]$ . $HOME/.bash_profile

# Run AWS configuration command
[user@workstation aws_devops]$ aws configure
AWS Access Key ID [****************ABCD]:
AWS Secret Access Key [****************1234]:
Default region name [us-east-1]:
Default output format [None]:

# Test AWS configuration - Expect lots of output
[user@workstation aws_devops]$ aws ec2 describe-instances --output text
```

## Create AWS network load balancers 

OpenShift requires two load balancers for proper cluster operation. 
If two NLB's do not already exist with associated DNS entries they will need to be created and DNS entries will need to be associated with them prior to cluster installation.

The nlb-create.sh script can be used to create pairs of NLB's to be used by OpenShift.

Required positional parameters:
* **1) Environment:** Environment OpenShift cluster will be deployed into (e.g. sandbox)
* **2) Subnet ID:** ID of AWS subnet the cluster will be deployed into (e.g. subnet-09372929)
* **3) Sequence:** If NLB pairs have already been created in the above environment this will be that number + 1 (i.e. If there are already 2 pairs of NLBs deployed in sandbox this will be 3)
* **4) Pairs:** The number of NLB pairs to create. (i.e. 2 if you want to create 4 NLB's to be used between 2 OpenShift clusters)

```shell
# Create two pairs of NLB's in subnet-99999999
[user@workstation aws_devops]$ ./scripts/nlb-create.sh example subnet-999999 1 2 
Creating 1 pair(s) of NLB's in subnet 10.1.1.18.0/24
Do you want to continue (Ctrl-C to abort)?
Creating example-nlb-9-be93-api
Created example-nlb-9-be93-api => example-nlb-9-be93-api-c744cf87a6b40d0b.elb.us-east-1.amazonaws.com
Creating example-nlb-9-be93-app
Created example-nlb-9-be93-app => example-nlb-9-be93-app-5c488c5cd32128ea.elb.us-east-1.amazonaws.com
```

There is also an associated script to list existing NLB's

```shell
# Existing NLB's can be listed using the nlb-list.sh command
[ecsaws@sd-9277-023a aws_devops]$ ./scripts/nlb-list.sh
us-east-1a example-nlb-9-be93-api 10.1.1.219 example-nlb-9-be93-api-c744cf87a6b40d0b.elb.us-east-1.amazonaws.com
us-east-1a example-nlb-9-be93-app 10.1.1.194 example-nlb-9-be93-app-5c488c5cd32128ea.elb.us-east-1.amazonaws.com
us-east-1a sandbox-nlb-1-b6cf-api 10.1.1.134 sandbox-nlb-1-b6cf-api-d877e2b487245964.elb.us-east-1.amazonaws.com
us-east-1a sandbox-nlb-1-b6cf-app 10.1.1.158 sandbox-nlb-1-b6cf-app-f2b9675aac6f172f.elb.us-east-1.amazonaws.com
```

Columns are:
* Availability zone
* NLB Name - Names ending in api are for masters, Names ending in app are for applications
* IP address
* AWS FQDN

## Create DNS entries

Each OpenShift cluster requires three DNS entries:
* **Public API:** Points to the IP address of the api NLB configured above (e.g. cluster01-webapi.aws.example.com)
* **Private API:** Points to the IP address of the api NLB configured above (e.g. cluster01-internal.aws.example.com)
* **Application Wildcard:** Points to the IP address of the app NLB configured above. Should be a wildcard dns entry (e.g. *.cluster01.aws.example.com)

**Note:** The installer creates a temporary DNS server on the Bastion host to allow an installation before the DNS entries are created, however the cluster will effectively be unusable until the DNS entries are created

# Deploying a cluster

## Using the deploy CLI tool

A python commandline tool has been written to simplify cluster operations with these playbooks. The examples below will demonstrate its use.

```shell
[user@workstation aws_devops]$ ./deploy --help
```

## Configure cluster template

Parameters that control the behavior of these playbooks can be found in the template [examples/cluster_template.yml.j2](examples/cluster_template.yml)
Typically the parameters found in this file are set on an environment to environment basis.

Copy this file to a separate location and modify the parameters as necessary

```shell
[user@workstation aws_devops]$ cp examples/cluster_template.yml.j2 /path/to/cluster_template.yml.j2
```

This file is used to generate cluster specific configurations that define all of the necessary configuration items for deployment

## Generate cluster configuration

A separate cluster configuration file is required for each cluster deployment and is used for all subsequent cluster administration (scaling up/down, teardown, health checks, etc)

This file is generated using the ```config``` deploy type.

Required parameters:
* **environment:** Cluster environment (e.g. dev, staging ,production, etc)
* **number:** Cardinal number of cluster in environment (e.g. 01)
* **az:** AWS availability zone (e.g. us-east-1b)
* **api_nlb:** Name of AWS Network Load Balancer to use for OpenShift API (e.g. staging-nlb-1-818f-api)
* **app_nlb:** Name of AWS Network Load Balancer to use for OpenShift application router (e.g staging-nlb-1-818f-app)
* **cluster_size:** Cluster sizing template to use for cluster infrastructure. Templates should be placed in [sizing-templates](sizing-templates) and the value of this flag should match a filename without the filetype suffix (e.g. large, medium)
* **template:** Path to cluster template. An unconfigured example can be found in [examples/cluster_template.yml.j2](examples/cluster_template.yml.j2) (e.g. /path/to/cluster_template.yml.j2)

```shell
[user@workstation aws_devops]$ ./deploy config \
                                   --environment staging \
                                   --number 05 \
                                   --az us-east-1a \
                                   --api_nlb staging-nlb-1-818f-api \
                                   --app_nlb staging-nlb-1-818f-app \
                                   --cluster_size large
                                   --template /path/to/cluster_template.yml.j2
```

Based on the above parameters a file ```staging05-config.yml``` will get generated in the root of this repository.

## Install OpenShift cluster

Installation of OpenShift clusters is carried out using the ```install``` deploy type.

Required parameters:
* **config:** Path to generated cluster configuration (e.g. /path/to/cluster01-config.yml)

```shell
# Deploy AWS infrastructure
[user@workstation aws_devops]$ ./deploy install --config /path/to/cluster01-config.yml
```

When installation is complete an OpenShift hosts file is generated and placed at the path specified in [defaults/main.yml](defaults/main.yml), typically ~/etc/ansible/inventory/.
This file is needed for subsequent cluster administration (scaling up/down, health checking, etc). It is very important to always use the most recently generated hosts file.

# Post-installation administration

## Post-installation validation

Running health checks against a running cluster is carried out using the ```health``` deploy type.

Required parameters:
* **config:** Path to generated cluster configuration (e.g. /path/to/cluster01-config.yml)
* **hosts_file:** Path to most recent hosts file (e.g. /path/to/cluster01-hosts)

```shell
[user@workstation aws_devops]$ ./deploy health --config /path/to/cluster01-config.yml --hosts_file /path/to/cluster01-hosts
```

## Scaling capacity

Application nodes can be scaled up/down using the ```scale``` deploy type.

The cluster will be scale up automatically if the desired number of application nodes exceeds the current number.
Conversely the cluster will be scaled down if the desired number of application nodes is less that the current number.

Required parameters:
* **config:** Path to generated cluster configuration (e.g. /path/to/cluster01-config.yml)
* **hosts_file:** Path to most recent hosts file (e.g. /path/to/cluster01-hosts)
* **desired_nodes:** Desired number of application nodes after scaling has completed. You can only add an additional 100 nodes at a time
* **asg_name:** Auto scaling group name for the auto scaling group you wish to scale. Found in the cluster config file or in the corresponding [sizing-template](sizing-templates) under ```app_asgs[].name``` (e.g. base)

```shell
[user@workstation aws_devops]$ ./deploy scale --config /path/to/cluster01-config.yml --hosts_file /path/to/cluster01-hosts --desired_nodes 10 --asg_name base
```

When installation is complete an OpenShift hosts file is generated and placed at the path specified in [defaults/main.yml](defaults/main.yml), typically ~/etc/ansible/inventory/.
This file is needed for subsequent cluster administration (scaling up/down, health checking, etc). It is very important to always use the most recently generated hosts file.

It is possible to scale multiple application node auto scaling groups simultaneously as long as you are scaling in the same direction (i.e. multiple up or multiple down).
It is **not advised** to scale multiple groups different directions simultaneously (i.e. scaling one group up and one group down at the same time).

## Tearing down a cluster

Clusters can be deleted using the ```teardown``` deploy type. 
Be **very** sure you have input the correct information before running this as this process cannot be undone.

Required parameters:
* **config:** Path to generated cluster configuration (e.g. /path/to/cluster01-config.yml)

```shell
[user@workstation aws_devops]$ ./deploy teardown --config /path/to/cluster01-config.yml
```

# Miscellaneous

## Generating an AMI

To generate an AMI that has the prerequisites for OpenShift cluster install already configured you will need to copy the [examples/ami.yml](examples/ami.yml) and input the required values.

The ami can then be generated using the ```ami``` deploy type.

Required parameters:
* **config:** Path to ami.yml configuration file with correct values. An example can be found at [examples/ami.yml](examples/ami.yml) (e.g. /path/to/cluster01-config.yml)

```shell
[user@workstation aws_devops]$ ./deploy ami --config /path/to/ami.yml
```

Once the AMI is generated you can use it by modifying the ami_id parameter found either in the [examples/cluster_template.yml.j2](examples/cluster_template.yml.j2) or the individual cluster configuration that was generated via ```./deploy config ...```.

## Printing cluster information

To print information about currently deployed clusters you can use the ```info``` deploy type.

```shell
[user@workstation aws_devops]$ ./deploy info --list_clusters
```

## Common commands

### Listing objects

```shell
# List all master nodes for cluster01 where cluster01 is cluster id
[user@workstation aws_devops]$ aws ec2 describe-instances --filters Name=tag:Name,Values=cluster01-master-node-asg | jq

# List all infrastructure nodes for cluster01 where cluster01 is cluster id
[user@workstation aws_devops]$ aws ec2 describe-instances --filters Name=tag:Name,Values=cluster01-infra-node-asg | jq

# List all application nodes for cluster01 where cluster01 is cluster id and base is autoscaling group name
[user@workstation aws_devops]$ aws ec2 describe-instances --filters Name=tag:Name,Values=cluster01-base-app-node-asg | jq

# List all EC2 instances in application autoscaling group base in cluster01 where base is auto scaling group type and cluster01 is cluster id
[user@workstation aws_devops]$ aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names cluster01-base-app-node-asg --query 'AutoScalingGroups[0].Instances' | jq

# List all cloudformation stacks
[user@workstation aws_devops]$ aws cloudformation describe-stacks | jq '.Stacks[].StackName'

# List all autoscaling groups
[user@workstation aws_devops]$ aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[].AutoScalingGroupName'
```

### Working with AMI's

```shell
# List AMI's owned by account
[user@workstation aws_devops]$ aws ec2 describe-images --owners self

# List AMI created by these playbooks
[user@workstation aws_devops]$ aws ec2 describe-images --filters Name=tag:Name,Values=<ami_name>" 

# Delete AMI
[user@workstation aws_devops]$ aws ec2 deregister-image --image-id <ami_id>
```

### SSH to cluster nodes using shorthands

During cluster installation SSH configuration is generated in such way that you can easily SSH to a node of a particular type.
This is most useful when you do not care _which_ node you SSH to, just that it is a master, infra, app, or bastion node.

The SSH shorthand is of format ```<cluster_id>-<node_type>```

```shell
# SSH to bastion for cluster01
[user@workstation aws_devops]$ ssh cluster01-bastion

# SSH to master for cluster01
[user@workstation aws_devops]$ ssh cluster01-master

# SSH to infra for cluster01
[user@workstation aws_devops]$ ssh cluster01-infra

# SSH to app for cluster01
[user@workstation aws_devops]$ ssh cluster01-app
```

### Pull down corporate resource certificate

```shell
openssl s_client -showcerts -connect <host>:<port> 2>&1 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ~/etc/ansible/certificates/<host>.pem
```

### Dealing with auto scaling

```shell
# Delete all nodes reporting NotReady from cluster
[user@workstation aws_devops]$ for i in $(oc get nodes --no-headers | grep NotReady | awk '{ print $1 }'); do oc delete node $i; done

# List number of instances in autoscaling group sandbox02-app-c-app-node-asg
[user@workstation aws_devops]$ aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[] | select(.AutoScalingGroupName | contains("sandbox02-app-c-app-node-asg"))' | jq '.Instances | length'

# Manually set auto scaling group capacity for group sandbox01-app-c-app-node-asg to 0
[user@workstation aws_devops]$ aws autoscaling update-auto-scaling-group --auto-scaling-group-name sandbox01-app-c-app-node-asg --desired-capacity 0
```

## Using Ansible callback plugins

There are a bunch of useful Ansible [callback plugins](https://docs.ansible.com/ansible/latest/plugins/callback.html)

Some of the more useful ones are timer, profile_tasks, and profile_roles. In addition to these a custom module has been written to print memory information on the hosts while ansible is running.

You can enable these plugins by uncommenting the ```callback_whitelist``` line in [ansible.cfg](ansible.cfg)
