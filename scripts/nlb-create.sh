#!/bin/bash
# The current architecture assumes two AWS Network Load Balancers will be pre-deployed and the DNS entries configured
# prior to deploying the OpenShift cluster. This script can be used to deploy the NLBs

# Unique name for the NLB's
NAME=$1
# AWS ID of the subnet to deploy the NLBs into
SUBNET_ID=$2
# 1 if there are no other NLBs deployed, n + 1 if there are already n pairs of NLBs deployed
SEQ_START=$3
# How many NLB pairs to deploy
NUM_PAIRS=$4

# Get AWS subnet information
CHECK=$(aws ec2 describe-subnets --subnet-id $SUBNET_ID | jq -r '.Subnets[].State')

# Fail if subnet does not exist
if [ "$CHECK" != 'available' ] ; then
	echo "Invalid subnet id: $SUBNET_ID"
	exit 1
fi

# Get AWS subnet CIDR block
CIDR=$(aws ec2 describe-subnets --subnet-id $SUBNET_ID | jq -r '.Subnets[].CidrBlock')

echo "Creating $NUM_PAIRS pair(s) of NLB's in subnet $CIDR"
read -p 'Do you want to continue (Ctrl-C to abort)?'

#Generates a new GUID then breaks out 4 unique characters
GUID=$(uuidgen | awk -F '-' '{print $2}')

# Create NLBs
for i in $( seq $SEQ_START $(( $SEQ_START+$NUM_PAIRS-1)) ); do 
    for type in api app ; do
        INS=$NAME-nlb-$i-$GUID-$type
        echo Creating $INS
        ARN=$(aws elbv2 create-load-balancer --name $INS  --type network --scheme internal --subnet-mappings SubnetId=$SUBNET_ID | jq -r '.LoadBalancers[].LoadBalancerArn')
        aws elbv2 modify-load-balancer-attributes --load-balancer-arn $ARN --attributes "Key=deletion_protection.enabled,Value=true" > /dev/null
        FQDN=$(aws elbv2 describe-load-balancers --load-balancer-arns $ARN | jq -r '.LoadBalancers[].DNSName')
        echo "Created $INS => $FQDN"
    done
done
