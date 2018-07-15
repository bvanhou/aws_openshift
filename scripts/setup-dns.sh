#!/bin/bash

MYDIR=$(dirname $0)

subnet=$1
host_suffix="$2"
shift 2
nameservers=$@

DNSMASQ_CFG=/etc/dnsmasq.d/ocp-ec2.conf
mkdir -p $(dirname $DNSMASQ_CFG)
HOSTS=/etc/hosts.ec2

# NS_LIST=$(sed -n -e '/127.0.0.1/d' -e 's/^ *nameserver *//p' < /etc/resolv.conf)

exec > $DNSMASQ_CFG

echo "# Generated $(date)"

for NS in $nameservers ; do
	[ -z "$NS" ] && continue
	[ $NS == none ] && continue
        echo server=$NS
done
echo no-hosts
echo addn-hosts=/etc/hosts.ec2

exec > $HOSTS

echo "Generating names for $subnet" >&2

$MYDIR/cidr-to-ip.sh $subnet | \
sed -n -e 's/^\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)$/\1.\2.\3.\4   ip-\1-\2-\3-\4.'$host_suffix'/p'

exit 0
