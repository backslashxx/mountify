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

# requires susfs add_try_umount
do_susfs_hide() {
for mount in $(grep "KSU" /proc/mounts | awk {'print $2'}) ; do 
	/data/adb/ksu/bin/ksu_susfs add_try_umount $mount 1
done
}

# requires modded ksud+driver with add-try-umount / nuke-ext4-sysfs
# this will unregister sparse when ext4 is enabled and spoof_sparse is disabled!
do_ksud_hide() {
if { [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; } && 
	[ "$spoof_sparse" = "0" ]; then	
	/data/adb/ksud nuke-ext4-sysfs "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	# /data/adb/ksud add-try-umount "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	busybox umount -l "$MNT_FOLDER/$FAKE_MOUNT_NAME"
fi

for mount in $(grep "KSU" /proc/mounts | awk {'print $2'}) ; do
	/data/adb/ksud add-try-umount $mount
done
}

# uncomment hiding method you want

# do_ksud_hide
# do_susfs_hide

# EOF
