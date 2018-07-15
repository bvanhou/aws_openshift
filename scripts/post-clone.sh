#!/bin/bash --

# Tasks to run after cloning repo
if [ ! -d ansible ] ; then
	echo "ansible directory does not exist - exiting" >&2
	exit 1
fi

mkdir -p ansible/ca-certs
cp -p /etc/pki/ca-trust/source/anchors/* ansible/ca-certs
rm -f ansible/ca-certs/ca.crt