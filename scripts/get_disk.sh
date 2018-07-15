#!/bin/bash

# Find first really unpartitioned/empty disk

lsblk -psnar -o TYPE,NAME | (
        CONTENT=no
        while read TYPE NAME ; do
                [ "$NAME" == /dev/fd0 ] && CONTENT=no && continue
                case "$TYPE" in
                rom ) CONTENT=no ;;
                disk )
                        if [ $CONTENT == no ] ; then
                                # Check for empty volume group
                                pvs -q --noheadings -o name $NAME > /dev/null 2>&1 || \
                                        echo $NAME && break
                        fi
                        CONTENT=no
                        ;;
                # Disk has content
                lvm | part | raid* )
                        CONTENT=yes
                        ;;
                * ) ;;
                esac
        done
)

exit 0