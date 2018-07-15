#!/bin/bash

# Usage scale-cluster config_file #_of_app_nodes

err_exit() {
        STATUS=$1
        shift
        echo $@ >&2
        exit $STATUS
}

MYDIR=$(dirname $0)

cd $MYDIR/../ansible || err_exit 1 "Can't find ansible directory"

ARGS=
case "$1" in
-* ) ARGS=$1
     shift
     ;;
esac

CONFIG=$1
TARGET=$2
[ -s "$CONFIG" ] || err_exit 1 "No such config file: $CONFIG"

CLUSTER=$( sed -n -e '/^\s*cluster_id:/s/^[^:]*\s*:\s*//p' < $CONFIG )
INVENTORY=$HOME/etc/ansible/inventory/$CLUSTER-hosts

echo "Scaling cluster up to $TARGET app nodes"

#ansible-playbook playbooks/scale_app_nodes.yml -i inventory -i $INVENTORY  --extra-vars "@$CONFIG" -e new_app_capacity=$TARGET
ansible-playbook playbooks/scaling/scale_app_up.yml $ARGS -i inventory -i $INVENTORY  --extra-vars "@$CONFIG" -e new_app_capacity=$TARGET
