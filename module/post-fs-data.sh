#!/bin/sh
# post-fs-data.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
# variables
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"
# config
mountify_mounts=2
mountify_use_susfs=0
FAKE_MOUNT_NAME="mountify"
# read config
. $MODDIR/config.sh
# exit if disabled
if [ $mountify_mounts = 0 ]; then
	exit 0
fi

# grab start time
echo "mountify/post-fs-data: start!" >> /dev/kmsg

# find and create logging folder
[ -w /tmp ] && LOG_FOLDER=/tmp/mountify
[ -w /sbin ] && LOG_FOLDER=/sbin/mountify
[ -w /debug_ramdisk ] && LOG_FOLDER=/debug_ramdisk/mountify
mkdir -p "$LOG_FOLDER"
# log before 
cat /proc/mounts > "$LOG_FOLDER/before"

# module mount section
IFS="
"
targets="odm
product
system_ext
vendor"
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# functions
# normal depth
normal_depth() {
	for DIR in $( ls -d */*/ | sed 's/.$//' ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		[ $mountify_use_susfs = 1 ] && ${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# controlled depth
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:$2$DIR" overlay "$2$DIR"
		[ $mountify_use_susfs = 1 ] && ${SUSFS_BIN} add_sus_mount "$2$DIR"
	done
}

# handle single depth on magic mount
single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//'  | grep -vE "^(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/system/$DIR" overlay "/system/$DIR"
		[ $mountify_use_susfs = 1 ] && ${SUSFS_BIN} add_sus_mount "/system/$DIR"
	done
}

# handle getfattr, it is sometimes not symlinked on /system/bin yet toybox has it
# I fucking hope magisk's busybox ships it sometime
if /system/bin/getfattr -d /system/bin > /dev/null 2>&1; then
	getfattr() { /system/bin/getfattr "$@"; }
else
	getfattr() { /system/bin/toybox getfattr "$@"; }
fi

# https://github.com/5ec1cff/KernelSU/commit/92d793d0e0e80ed0e87af9e39879d2b70c37c748
# on overlayfs, moddir/system/product is symlinked to moddir/product
# on magic, moddir/product it symlinked to moddir/system/product
if [ "$KSU_MAGIC_MOUNT" = "true" ] || [ "$APATCH_BIND_MOUNT" = "true" ] || { [ -f /data/adb/magisk/magisk ] && [ -z "$KSU" ] && [ -z "$APATCH" ]; }; then
	MAGIC_MOUNT=true
fi

mountify_copy() {
	# return for missing args
	if [ -z "$1" ]; then
		# echo "$(basename "$0" ) module_id fake_folder_name"
		echo "mountify/post-fs-data: missing arguments, fuck off" >> /dev/kmsg
		return
	fi

	MODULE_ID="$1"
	
	# return for certain modules
	# bindhosts manages itself, you dont want to global mount hosts file
	# De-bloater uses dummy text, not whiteouts, which does not really work
	if [ "$MODULE_ID" = "bindhosts" ] || [ "$MODULE_ID" = "De-bloater" ]; then
		echo "mountify/post-fs-data: module with name $MODULE_ID is blacklisted" >> /dev/kmsg
		return
	fi
	
	# test for various stuff
	TARGET_DIR="/data/adb/modules/$MODULE_ID"
	if [ ! -d "$TARGET_DIR/system" ] || [ -f "$TARGET_DIR/disable" ] || [ -f "$TARGET_DIR/remove" ] || [ -f "$TARGET_DIR/skip_mountify" ]; then
		echo "mountify/post-fs-data: module with name $MODULE_ID not meant to be mounted" >> /dev/kmsg
		return
	fi

	echo "mountify/post-fs-data: processing $MODULE_ID" >> /dev/kmsg

	# skip_mount is not needed on .nomount MKSU
	# we do the logic like this so that it catches all non-magic ksu
	# theres a chance that its an overlayfs ksu but still has .nomount file
	if [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; then 
		# delete skip_mount if nomount
		[ -f "$TARGET_DIR/skip_mount" ] && rm "$TARGET_DIR/skip_mount"
		[ -f "$MODDIR/skipped_modules" ] && rm "$MODDIR/skipped_modules"
	else
		if [ ! -f "$TARGET_DIR/skip_mount" ]; then
			touch "$TARGET_DIR/skip_mount"
			# log modules that got skip_mounted
			# we can likely clean those at uninstall
			echo "$MODULE_ID" >> $MODDIR/skipped_modules
		fi
	fi

	BASE_DIR=$MODULE_ID
	if [ "$MAGIC_MOUNT" = true ]; then
		# for magic mount, we can copy over contents of system folder only
		BASE_DIR="$MODULE_ID/system"
	fi
	
	# copy over our files
	cd "$MNT_FOLDER" && cp -rf /data/adb/modules/"$BASE_DIR"/* "$FAKE_MOUNT_NAME"

	# go inside
	cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

	# make sure to mirror selinux context
	# else we get "u:object_r:tmpfs:s0"
	for file in $( find ./ | sed "s|./|/|") ; do 
		busybox chcon --reference="/data/adb/modules/$BASE_DIR/$file" ".$file"  
	done

	# catch opaque dirs, requires getfattr
	for dir in $( find /data/adb/modules/$BASE_DIR -type d ) ; do
		if getfattr -d "$dir" | grep -q "trusted.overlay.opaque" ; then
			echo "mountify_debug: opaque dir $dir found!" >> /dev/kmsg
			opaque_dir=$(echo "$dir" | sed "s|"/data/adb/modules/$BASE_DIR"|.|")
			busybox setfattr -n trusted.overlay.opaque -v y "$opaque_dir"
			echo "mountify_debug: replaced $opaque_dir!" >> /dev/kmsg
		fi
	done

	# if it reached here, module probably copied, log it
	echo "$MODULE_ID" >> "$LOG_FOLDER/modules"
}

# make sure its not there
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# anti fuckup
	# this is important as someone might actually use legit folder names
	# and same shit exists on MNT_FOLDER, prevent this issue.
	echo "mountify/post-fs-data: exiting since fake folder name $FAKE_MOUNT_NAME already exists!" >> /dev/kmsg
	exit 1
fi

# create it
mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"
touch "$MNT_FOLDER/$FAKE_MOUNT_NAME/placeholder"

# then make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# weird if it happens
	echo "mountify/post-fs-data: failed creating folder with fake_folder_name $FAKE_MOUNT_NAME !" >> /dev/kmsg
	exit 1
fi

# if manual mode and modules.txt has contents
if [ $mountify_mounts = 1 ] && grep -qv "#" "$MODDIR/modules.txt" >/dev/null 2>&1 ; then
	# manual mode
	for line in $( sed '/#/d' "$MODDIR/modules.txt" ); do
		module_id=$( echo $line | awk {'print $1'} )
		mountify_copy "$module_id"
	done
else
	# auto mode
	for module in /data/adb/modules/*/system; do 
		module_id="$(echo $module | cut -d / -f 5 )"
		mountify_copy "$module_id"
	done
fi

# mount 
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"
if [ "$MAGIC_MOUNT" = true ] || [ "$MODULE_ID" = "mountify_whiteouts" ]; then
	# handle single depth on magic mount
	single_depth
	# handle this stance when /product is a symlink to /system/product
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
else
	normal_depth
fi

# log after
cat /proc/mounts > "$LOG_FOLDER/after"
echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
