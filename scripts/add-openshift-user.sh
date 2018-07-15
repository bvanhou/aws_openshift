#!/bin/bash

PASSFILE=$HOME/etc/ansible/htpasswd

touch $PASSFILE

chmod 600 $PASSFILE

htpasswd -b $PASSFILE $1 $2

exit 0

