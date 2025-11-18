#!/bin/sh
# boot-completed.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
# read config
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh

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

# requires modded ksud+driver with add-try-umount
# umount via zygisk umount provider is still better.
# this is here for reference purposes and as a second choice
do_ksud_umount() {
for mount in $(cat "$LOG_FOLDER/mountify_mount_list"); do
	/data/adb/ksud kernel umount add $mount --flags 2 > /dev/null 2>&1
	# now inform ksud so that the kernel unlocks the feature
	/data/adb/ksud kernel notify-module-mounted >/dev/null 2>&1
done
}

if [ "$mountify_custom_umount" = 1 ]; then
	do_susfs_umount
fi

if [ "$mountify_custom_umount" = 2 ]; then
	do_ksud_umount
fi

# cleanup
# prep logs for status
busybox diff "$LOG_FOLDER/before" "$LOG_FOLDER/after" | grep " $FS_TYPE_ALIAS " > "$MODDIR/mount_diff"

# clean log folder
[ -d "$LOG_FOLDER" ] && rm -rf "$LOG_FOLDER"

# EOF
