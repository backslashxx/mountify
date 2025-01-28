#!/bin/sh
# mount.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"
mountify_mounts=0
# read config
. $MODDIR/config.sh
# exit if disabled
if [ $mountify_mounts = 0 ]; then
	exit 0
fi

# exit for missing args
if [ -z "$1" ] || [ -z "$2" ]; then
	# echo "$(basename "$0" ) module_id fake_folder_name"
	echo "mountify/mount: missing arguments, fuck off" >> /dev/kmsg
	exit 1
fi

MODULE_ID="$1"
FAKE_MOUNT_NAME="$2"

TARGET_DIR="/data/adb/modules/$MODULE_ID"
if [ ! -d "$TARGET_DIR" ] || [ -f "$TARGET_DIR/disable" ] || [ -f "$TARGET_DIR/remove" ] || [ "$MODULE_ID" = "bindhosts" ]; then
	echo "mountify/mount: module with name $MODULE_ID does NOT exist or not meant to be mounted" >> /dev/kmsg
	exit 1
fi

echo "mountify/mount: processing $MODULE_ID with $FAKE_MOUNT_NAME as fake name" >> /dev/kmsg

# skip_mount is not needed on .nomount MKSU
# we do the logic like this so that it catches all non-magic ksu
# theres a chance that its an overlayfs ksu but still has .nomount file
if [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; then 
	true
else
	[ ! -f "$TARGET_DIR/skip_mount" ] && touch "$TARGET_DIR/skip_mount"
fi

# here we do the vendor mount mimic
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# make sure its not there
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# anti fuckup
	# this is important as someone might actually use legit folder names
	# and same shit exists on MNT_FOLDER, prevent this issue.
	echo "mountify/mount: skipping $MODULE_ID with fake folder name $FAKE_MOUNT_NAME as it already exists!" >> /dev/kmsg
	exit 1
fi

# create it
cd "$MNT_FOLDER" && cp -r "/data/adb/modules/$MODULE_ID" "$FAKE_MOUNT_NAME"

# then make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# weird if it happens
	echo "mountify/mount: failed creating folder with fake_folder_name $FAKE_MOUNT_NAME !" >> /dev/kmsg
	exit 1
fi

# go inside
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# make sure to mirror selinux context
# else we get "u:object_r:tmpfs:s0"
IFS="
"
for file in $( find ./ | sed "s|./|/|") ; do 
	busybox chcon --reference="/data/adb/modules/$MODULE_ID/$file" ".$file"  
done

# handle getfattr, it is sometimes not symlinked on /system/bin yet toybox has it
# I fucking hope magisk's busybox ships it sometime
if /system/bin/getfattr -d /system/bin > /dev/null 2>&1; then
	getfattr() { /system/bin/getfattr "$@"; }
else
	getfattr() { /system/bin/toybox getfattr "$@"; }
fi

# catch opaque dirs, requires getfattr
for dir in $( find /data/adb/modules/$MODULE_ID -type d ) ; do
	if getfattr -d $dir | grep -q "trusted.overlay.opaque" ; then
		echo "mountify_debug: opaque dir $dir found!" >> /dev/kmsg
		opaque_dir=$(echo $dir | sed "s|"/data/adb/modules/$MODULE_ID"|.|")
		busybox setfattr -n trusted.overlay.opaque -v y "$opaque_dir"
		echo "mountify_debug: replaced $opaque_dir!" >> /dev/kmsg
	fi
done

targets="odm
product
system_ext
vendor"

# mounting functions
normal_depth() {
	for DIR in $(ls -d */*/); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# controlled depth
controlled_depth() {
	for DIR in $(ls -d $1/*/); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}


# handle single depth on magic mount
single_depth() {
	for DIR in $( ls -d system/apex/ system/app/ system/bin/ system/etc/ system/fonts/ system/framework/ system/lib/ system/lib64/ system/priv-app/ system/usr/ 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# https://github.com/5ec1cff/KernelSU/commit/92d793d0e0e80ed0e87af9e39879d2b70c37c748
# on overlayfs, moddir/system/product is symlinked to moddir/product
# on magic, moddir/product it symlinked to moddir/system/product
if [ "$KSU_MAGIC_MOUNT" = "true" ] || [ "$APATCH_BIND_MOUNT" = "true" ] || { [ -f /data/adb/magisk/magisk ] && [ -z "$KSU" ] && [ -z "$APATCH" ]; }; then
	# handle single depth on magic mount
	single_depth
	# handle this stance when /product is a symlink to /system/product
	for folder in $targets ; do 
		# reset cwd due to loop
		cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"
		if [ -L "/$folder" ] && [ ! -L "/system/$folder" ]; then
			controlled_depth "system/$folder"
		else
			cd system && controlled_depth "$folder"
		fi
	done
else
	normal_depth
fi

# EOF
