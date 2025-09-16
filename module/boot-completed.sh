#!/bin/sh
# boot-completed.sh
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

[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# add mounts to list

# add sparse first
# on ext4 mode and sparse isn't spoofed
if { [ -f "$MODDIR/xattr_fail" ] || [ "$use_ext4_sparse" = "1" ]; } && [ "$spoof_sparse" = "0" ];then
	# add to umount
	"$MODDIR/prctl" 0xdeadbeef 10001 "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	# unregister sparse's ext4 node
	"$MODDIR/prctl" 0xdeadbeef 10002 "$MNT_FOLDER/$FAKE_MOUNT_NAME"
fi

# this assumer ksu is your mount device name
# if $MOUNT_DEVICE_NAME is used to grep, it can grep "overlay" and will unmount all overlays !!
for mount in $(grep "KSU" /proc/mounts | awk {'print $2'}) ; do
        # add mounts to list
	"$MODDIR/prctl" 0xdeadbeef 10001 $mount
done

# lousy maphide
# "$MODDIR/prctl" 0xdeadbeef 0x11001 libqdMetaData.so

# EOF

