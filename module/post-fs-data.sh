#!/bin/sh
# post-fs-data.sh
# this script is part of mountify (symlink ver)
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"
MODDIR="/data/adb/modules/mountify"

# config
mountify_mounts=1
MOUNT_DEVICE_NAME="overlay"
FS_TYPE_ALIAS="overlay"
FAKE_MOUNT_NAME="mountify"
PERSISTENT_DIR="/data/adb/mountify"
# read config
. $PERSISTENT_DIR/config.sh
# exit if disabled
if [ $mountify_mounts = 0 ]; then
	exit 0
fi

# add simple anti bootloop logic
BOOTCOUNT=0
[ -f "$MODDIR/count.sh" ] && . "$MODDIR/count.sh"

BOOTCOUNT=$(( BOOTCOUNT + 1))

if [ $BOOTCOUNT -gt 1 ]; then
	touch $MODDIR/disable
	rm "$MODDIR/count.sh"
	string="description=anti-bootloop triggered. module disabled. enable to activate."
	sed -i "s/^description=.*/$string/g" $MODDIR/module.prop
	exit 1
else
	echo "BOOTCOUNT=1" > "$MODDIR/count.sh"
fi

# this is a fast lookup for a writable dir
# these tends to be always available
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor
LOG_FOLDER="$MNT_FOLDER/mountify_logs"
mkdir -p "$LOG_FOLDER"
# log before 
cat /proc/mounts > "$LOG_FOLDER/before"

IFS="
"
targets="odm
product
system_ext
vendor"

# check if fake alias exists, if fail use overlay
if ! grep "nodev" /proc/filesystems | grep -q "$FS_TYPE_ALIAS" > /dev/null 2>&1; then
	FS_TYPE_ALIAS="overlay"
fi

# functions
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR"
	done
}

single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//'  | grep -vE "^(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" /system/$DIR
	done
}

mountify_symlink() {
if [ -z "$1" ] || [ -z "$2" ]; then
	echo "mountify/post-fs-data: missing arguments, fuck off" >> /dev/kmsg
	return
fi

if [ -f "/data/adb/modules/$1/disable" ] || [ -f "/data/adb/modules/$1/remove" ] || [ ! -d "/data/adb/modules/$1/system" ] ||
	[ -f "/data/adb/modules/$1/skip_mountify" ] || [ -f "/data/adb/modules/$1/system/etc/hosts" ]; then
	echo "mountify/post-fs-data: $1 not meant to be mounted" >> /dev/kmsg
	return	
fi

if [ -f "/data/adb/modules/$1/skip_mount" ] && [ -f "$MODDIR/metamount.sh" ]; then
	echo "mountify/post-fs-data: $1 has skip_mount" >> /dev/kmsg
fi

echo "mountify/post-fs-data: processing $1" >> /dev/kmsg
	
# skip_mount is not needed on .nomount MKSU - 5ec1cff/KernelSU/commit/76bfccd
# skip_mount is also not needed for litemode APatch - bmax121/APatch/commit/7760519
if { [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; } ||
	{ [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; } ||
	[ -f "$MODDIR/metamount.sh" ]; then 

	# ^ HACK: the metamodule check is here just so it wont create a skip_mount flag.
	# we do NOT have 'goto' in shell so we to keep it this way.
	# since we already check it above, it should NOT be here!

	[ -f "/data/adb/modules/$1/skip_mount" ] && rm "/data/adb/modules/$1/skip_mount"
	[ -f "$MODDIR/skipped_modules" ] && rm "$MODDIR/skipped_modules"
else
	if [ ! -f "$TARGET_DIR/skip_mount" ]; then
		touch "/data/adb/modules/$1/skip_mount"
		# log modules that got skip_mounted
		# we can likely clean those at uninstall
		echo "$1" >> $MODDIR/skipped_modules
	fi
fi

MODULE_BASEDIR="/data/adb/modules/$1/system"
SUBFOLDER_NAME="$2"
	
# here we create the symlink
busybox ln -sf "$MODULE_BASEDIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME/$SUBFOLDER_NAME"

if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME/$SUBFOLDER_NAME" ]; then
	return
fi
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME/$SUBFOLDER_NAME"

# single_depth
single_depth
# controlled depth
for folder in $targets ; do 
	# reset cwd due to loop
	cd "$MNT_FOLDER/$FAKE_MOUNT_NAME/$SUBFOLDER_NAME"
	if [ -L "/$folder" ] && [ ! -L "/system/$folder" ]; then
		# legacy, so we mount at /system
		controlled_depth "$folder" "/system/"
	else
		# modern, so we mount at root
		controlled_depth "$folder" "/"
	fi
done

# if it reached here, module probably copied, log it
echo "$1" >> "$LOG_FOLDER/modules"

} # mountify_symlink

# I dont think auto mode is possible right away
# logic seems hard as we have to /mnt/vendor/module1/system/app:/mnt/vendor/module2/system/app
# PR welcome if somebody sees a way to do it easily.
# so ye manual for now

mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# create our own tmpfs
mount -t tmpfs tmpfs "$MNT_FOLDER/$FAKE_MOUNT_NAME"

count=0
if [ $mountify_mounts = 1 ] && grep -qv "#" "$PERSISTENT_DIR/modules.txt" >/dev/null 2>&1 ; then
	for line in $( sed '/#/d' "$PERSISTENT_DIR/modules.txt" ); do
		module_id=$( echo $line | awk {'print $1'} )
		mountify_symlink "$module_id" "0000$count"
		count=$(( count + 1 ))
	done
else
	# auto mode
	for module in /data/adb/modules/*/system; do 
		module_id="$(echo $module | cut -d / -f 5 )"
		mountify_symlink "$module_id" "0000$count"
		count=$(( count + 1 ))
	done
fi

# unmout our own tmpfs
umount -l "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# log after
cat /proc/mounts > "$LOG_FOLDER/after"
echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
