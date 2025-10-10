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

# feel free to modify this script as you need, depending on methods
# you use to unmount or a method to hide ext4 sparse /proc/fs node if
# youre on ext4 mode. maybe in the future a KPM can do it or something.
# - xx
#
# this script will be migrated by mountify re-installs / updates
#

[ -w /mnt ] && MNT_FOLDER=/mnt && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor && LOG_FOLDER=/mnt/vendor/mountify_logs

# requires susfs add_try_umount
do_susfs_umount() {
for mount in $(cat "$LOG_FOLDER/mountify_mount_list") ; do 
	/data/adb/ksu/bin/ksu_susfs add_try_umount $mount 1
done
}

# requires modded ksud+driver with nuke-ext4-sysfs
# this will unregister sparse when ext4 is enabled and spoof_sparse is disabled!
do_ext4_nuke() {
if { [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; } && 
	[ "$spoof_sparse" = "0" ]; then	
	/data/adb/ksud nuke-ext4-sysfs "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	busybox umount -l "$MNT_FOLDER/$FAKE_MOUNT_NAME"
fi
}

# requires modded ksud+driver with add-try-umount
# umount via zygisk umount provider is still better.
# this is here for reference purposes and as a second choice
do_ksud_umount() {
for mount in $(grep "$FAKE_MOUNT_NAME" /proc/mounts | awk {'print $2'}) ; do
	/data/adb/ksud add-try-umount $mount
done
}

# uncomment hiding method you want

# for sekrit club ksud uncomment these two options as you need
# do_ext4_nuke
# do_ksud_umount

# for susfs, uncomment if you need
# do_susfs_umount

# EOF
