#!/bin/bash --

aws elbv2 describe-load-balancers | jq -j '.LoadBalancers[]| .AvailabilityZones[].ZoneName," ",.LoadBalancerName," ",.DNSName,"\n"' | sort | while read AZ LB FQDN ; do
	IP=$( host $FQDN | sed -n -e '/address/s/^.* //p' )
	[ -z "$IP" ] && IP="NOT ALLOCATED"
	echo $AZ $LB $IP $FQDN
done
