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

# handle operating mode
case $mountify_mounts in
	1) mode="manual 🤓" ;;
	2) mode="auto 🤖" ;;
	*) mode="disabled 💀" ;; # ??
esac

if [ -f "$LOG_FOLDER/mountify_symlink" ]; then
	mode="$mode | ???: symlink 🔗"
elif [ "$use_ext4_sparse" = "1" ] || [ -f "$MODDIR/no_tmpfs_xattr" ]; then
	mode="$mode | fstype: ext4 🛠️"
else
	mode="$mode | fstype: tmpfs 🦾"
fi

# display if on litemode
if [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; then 
	mode="$mode | litemode: ✅"
fi

# wait for boot-complete
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 1
done

# reset bootcount (anti-bootloop routine)
echo "BOOTCOUNT=0" > "$MODDIR/count.sh"

if [ ! "$APATCH" = true ] && [ ! "$KSU" = true ]; then
	sh "$MODDIR/boot-completed.sh" &
fi

# remove mountify single instance lock
MOUNTIFY_LOCK="/dev/mountify_single_instance"
if [ -f "$MOUNTIFY_LOCK" ]; then
	echo "mountify/service: lifting single instance lock" >> /dev/kmsg
	rm "$MOUNTIFY_LOCK"
fi

# update description accrdingly
string="description=mode: $mode | no modules mounted"
if [ -f $LOG_FOLDER/modules ]; then
	module_list=$( for module in $(cat "$LOG_FOLDER/modules" ) ; do printf "$module " ; done )
	string="description=mode: $mode | modules: $module_list "
fi
cat "$MODDIR/module.prop" > "$MODDIR/module.prop.tmp"
busybox sed -i "s/^description=.*/$string/g" "$MODDIR/module.prop.tmp"
busybox mv -f "$MODDIR/module.prop.tmp" "$MODDIR/module.prop"

# clean log folder
[ -d "$LOG_FOLDER" ] && rm -rf "$LOG_FOLDER"

# EOF
