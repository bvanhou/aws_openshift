#!/bin/bash --

# For customers that choose to use a different DNS suffix for
# provate IP's.
# Run standard Ansible ec2 inventory script replacing ec2.internal with
# customers DNS suffix

MYDIR=$(dirname $0)

[ -z "$EC2_INI_PATH" -a -s "$PWD/ec2.ini" ] && export EC2_INI_PATH=$PWD/ec2.ini
[ -z "$EC2_INI_PATH" -a -s "$MYDIR/ec2.ini" ] && export EC2_INI_PATH=$MYDIR/ec2.ini

[ -s "$MYDIR/../variables/default_parameters.yml" ] && \
	HOST_SUFFIX=$(sed -n -e '/^host_suffix:/s/^.*: *//p' < $MYDIR/../variables/default_parameters.yml)
# Remove any quotes
eval HOST_SUFFIX=$( echo $HOST_SUFFIX )

if [ -n "${HOST_SUFFIX}}" ] ; then
	$HOME/bin/ec2.sh $@ | sed -e "/ec2_private_dns_name/s/\.[^\"]*/.${HOST_SUFFIX}/"
else
	$HOME/bin/ec2.sh $@
fi
