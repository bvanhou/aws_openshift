#!/bin/bash

CLUSTER=$1

aws cloudformation describe-stacks | jq -r '.Stacks[].StackName' | sort | grep -E "^${CLUSTER}-(ocp|openshift)-" | (
while read STACK ; do
	echo $STACK
	sleep 1
	aws cloudformation delete-stack --stack-name $STACK
done
)

aws elbv2 describe-target-groups | jq -j '.TargetGroups[]| .TargetGroupArn," ", .LoadBalancerArns[],"\n"' | sort -u | (
while read TG_ARN LB_ARN ; do
	case $TG_ARN in
	*targetgroup/$CLUSTER-* ) ;;
	* ) continue ;;
	esac

	echo Deleting $TG_ARN
	sleep 1
        if [ -n "$LB_ARN" ] ; then
		for LIS_ARN in $( aws elbv2 describe-listeners --load-balancer-arn $LB_ARN | jq -r ".Listeners[].ListenerArn" ) ; do
			aws elbv2 delete-listener --listener-arn $LIS_ARN
		done
	fi

	aws elbv2 delete-target-group --target-group-arn $TG_ARN
done
)
