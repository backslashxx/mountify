#!/bin/sh
# service.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
# read config
. $MODDIR/config.sh

#
# this script will be migrated by mountify re-installs / updates
#

# put your whatever in here
# example
# unmount my mounts via susfs
# for mount in $(grep $MOUNT_DEVICE_NAME /proc/mounts | awk {'print $2'}) ; do 
#	/data/adb/ksu/bin/ksu_susfs add_try_umount $mount 1
# done

# EOF
