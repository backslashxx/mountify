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

# feel free to modify this script as you need
# - xx
#
# this script will be migrated by mountify re-installs / updates
#

[ -w /mnt ] && MNT_FOLDER=/mnt && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor && LOG_FOLDER=/mnt/vendor/mountify_logs

# requires susfs add_try_umount
do_susfs_umount() {
for mount in $(cat "$LOG_FOLDER/mountify_mount_list") ; do 
	# workaround for oplus devices
	if echo "$mount" | grep -q "/my_" ; then
		/data/adb/ksu/bin/ksu_susfs add_try_umount "/mnt/vendor$mount" 1
	fi
	/data/adb/ksu/bin/ksu_susfs add_try_umount "$mount" 1
done
}

# for susfs, uncomment if you need
# do_susfs_umount

# cleanup
# prep logs for status
busybox diff "$LOG_FOLDER/before" "$LOG_FOLDER/after" | grep " $FS_TYPE_ALIAS " > "$MODDIR/mount_diff"

# clean log folder
[ -d "$LOG_FOLDER" ] && rm -rf "$LOG_FOLDER"

# EOF
