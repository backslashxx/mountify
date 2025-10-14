#!/bin/sh
# after-post-fs-data.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
# read config
. $MODDIR/config.sh

# feel free to modify this script as you need
# this script is executed at post-fs-data by mountify
# be mindful that post-fs-data scripts are blocking
# this script will be migrated by mountify re-installs / updates

[ -w /mnt ] && MNT_FOLDER=/mnt && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor && LOG_FOLDER=/mnt/vendor/mountify_logs

# requires modded ksud+driver with nuke-ext4-sysfs
# this will unregister sparse when ext4 is enabled and spoof_sparse is disabled!
do_ext4_nuke() {
if [ ! $enable_lkm_nuke = 1 ] && [ "$spoof_sparse" = "0" ] && 
	{ [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; }; then
	/data/adb/ksud nuke-ext4-sysfs "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
	busybox umount -l "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
fi
}

# uncomment hiding method you want

# for sekrit club ksud uncomment these two options as you need
# do_ext4_nuke

# EOF
