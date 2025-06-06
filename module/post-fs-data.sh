#!/bin/sh
# post-fs-data.sh
# this script is part of mountify (symlink ver)
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

# this is a fast lookup for a writable dir
# these tends to be always available
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor
LOG_FOLDER="$MNT_FOLDER/mountify_logs"
mkdir -p "$LOG_FOLDER"

IFS="
"
targets="odm
product
system_ext
vendor"

controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:$2$DIR" overlay "$2$DIR"
	done
}

single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//'  | grep -vE "^(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/system/$DIR" overlay /system/$DIR
	done
}

mountify_symlink() {
if [ -z "$1" ] || [ -z "$2" ]; then
	echo "mountify/post-fs-data: missing arguments, fuck off" >> /dev/kmsg
	return
fi

if [ "$1" = "bindhosts" ]; then
	echo "mountify/post-fs-data: $1 blacklisted" >> /dev/kmsg
	return
fi	

if [ -f "/data/adb/modules/$1/skip_mountify" ] || [ -f "/data/adb/modules/$1/disable" ] || [ -f "/data/adb/modules/$1/remove" ] || [ ! -d "/data/adb/modules/$1/system" ]; then
	echo "mountify/post-fs-data: $1 not meant to be mounted" >> /dev/kmsg
	return	
fi

echo "mountify/post-fs-data: processing $1" >> /dev/kmsg
	
# skip_mount is not needed on .nomount MKSU - 5ec1cff/KernelSU/commit/76bfccd
# skip_mount is also not needed for litemode APatch - bmax121/APatch/commit/7760519
if { [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; } || { [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; }; then 
	# we can delete skip_mount if nomount / litemode
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
FAKE_MOUNT_NAME="$2"
	
# here we create the symlink
busybox ln -sf "$MODULE_BASEDIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME"

if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	return
fi
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# single_depth
single_depth
# controlled depth
for folder in $targets ; do 
	# reset cwd due to loop
	cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"
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

}

# I dont think auto mode is possible right away
# logic seems hard as we have to /mnt/vendor/module1/system/app:/mnt/vendor/module2/system/app
# PR welcome if somebody sees a way to do it easily.
# so ye manual for now

# manual mode
for line in $( sed '/#/d' "$MODDIR/modules.txt" ); do
	module_id=$( echo $line | awk {'print $1'} )
	mount_name=$( echo $line | awk {'print $2'} )
	mountify_symlink "$module_id" "$mount_name"
done

# EOF
