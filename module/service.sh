#!/bin/sh
# service.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
mountify_stop_start=0
# read config
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh

# stop; start
# restart android at service
# this is a bit of a workaround for "racey" modules.
# I do NOT know how to explain it, but it is like on some modules
# mounting is LATE. this happens especially with certain gpu drivers
# and even as simple as bootanimation modules.
# if you do NOT have the issue, you do NOT need this.
# this is disabled by default on config.sh
# NOTE: ksu 32331 it might be smart to force android restart on late load
# https://github.com/tiann/KernelSU/commit/f0615d3ce40decf27e3d89ed3aec437b2df33ed7
if [ $mountify_stop_start = 1 ] || [ "$KSU_LATE_LOAD" = "1" ]; then
	stop; start
fi

# handle kernel umount
LOG_FOLDER="/dev/mountify_logs"

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

# requires ksu 22105+
do_ksud_umount() {
for mount in $(cat "$LOG_FOLDER/mountify_mount_list"); do
	/data/adb/ksud kernel umount add "$mount" --flags 2 > /dev/null 2>&1
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

if [ ! "$APATCH" = true ] && [ ! "$KSU" = true ]; then
	until [ "$(getprop sys.boot_completed)" = "1" ]; do
		sleep 1
	done
	sh "$MODDIR/boot-completed.sh" &
fi

# EOF
