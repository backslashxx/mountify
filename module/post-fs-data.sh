#!/bin/sh
# post-fs-data.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
# variables
MODDIR="/data/adb/modules/mountify"
# config
mountify_mounts=2
FAKE_MOUNT_NAME="mountify"
MOUNT_DEVICE_NAME="overlay"
FS_TYPE_ALIAS="overlay"
use_ext4_sparse=0
spoof_sparse=0
FAKE_APEX_NAME="com.android.mntservice"
sparse_size="2048"
test_decoy_mount="0"
DECOY_MOUNT_FOLDER="/oem"
# read config
. $MODDIR/config.sh
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

# grab start time
echo "mountify/post-fs-data: start!" >> /dev/kmsg

# find and create logging folder
[ -w /mnt ] && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && LOG_FOLDER=/mnt/vendor/mountify_logs
mkdir -p "$LOG_FOLDER"
# log before 
cat /proc/mounts > "$LOG_FOLDER/before"

# module mount section
IFS="
"
targets="odm
product
system_ext
vendor
mi_ext
my_bigball
my_carrier
my_company
my_engineering
my_heytap
my_manifest
my_preload
my_product
my_region
my_reserve
my_stock"

decoy_folder_candidates="/oem
/second_stage_resources
/patch_hw
/postinstall
/system_dlkm
/oem_dlkm
/acct
"

[ -w /mnt ] && MNT_FOLDER="/mnt"
[ -w /mnt/vendor ] && MNT_FOLDER="/mnt/vendor"

# check if fake alias exists, if fail use overlay
if ! grep "nodev" /proc/filesystems | grep -q "$FS_TYPE_ALIAS" > /dev/null 2>&1; then
	FS_TYPE_ALIAS="overlay"
fi

if [ "$test_decoy_mount" = "1" ] && [ ! -f "$MODDIR/no_tmpfs_xattr" ]; then
	# test for decoy mount
	# it needs to be a blank folder
	for dir in $decoy_folder_candidates; do
		if [ -d "$dir" ] && [ "$(ls -A "$dir" 2>/dev/null | wc -l)" -eq 0 ]; then
			DECOY_MOUNT_FOLDER="$dir"
			echo "mountify/post-fs-data: decoy folder $DECOY_MOUNT_FOLDER" >> /dev/kmsg
			decoy_mount_enabled="1"
			break
		fi
	done
fi

# functions

# controlled depth ($targets fuckery)
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		if [ "$decoy_mount_enabled" = "1" ] && [ -w "$DECOY_MOUNT_FOLDER" ]; then
			mkdir -p "$DECOY_MOUNT_FOLDER/$FAKE_MOUNT_NAME$2$DIR"
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$DECOY_MOUNT_FOLDER/$FAKE_MOUNT_NAME$2$DIR:$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR"
		else
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR"
		fi
	done
}

# handle single depth (/system/bin, /system/etc, et. al)
single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//'  | grep -vE "^(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		if [ "$decoy_mount_enabled" = "1" ] && [ -w "$DECOY_MOUNT_FOLDER" ]; then
			mkdir -p "$DECOY_MOUNT_FOLDER/$FAKE_MOUNT_NAME/system/$DIR"
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$DECOY_MOUNT_FOLDER/$FAKE_MOUNT_NAME/system/$DIR:$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" "/system/$DIR"
		else
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" "/system/$DIR"
		fi
	done
}

# handle getfattr, it is sometimes not symlinked on /system/bin yet toybox has it
# I fucking hope magisk's busybox ships it sometime
if /system/bin/getfattr -d /system/bin > /dev/null 2>&1; then
	getfattr() { /system/bin/getfattr "$@"; }
else
	getfattr() { /system/bin/toybox getfattr "$@"; }
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
	# De-bloater uses dummy text, not whiteouts, which does not really work
	if [ "$MODULE_ID" = "De-bloater" ]; then
		echo "mountify/post-fs-data: module with name $MODULE_ID is blacklisted" >> /dev/kmsg
		return
	fi
	
	# test for various stuff
	# you dont want to global mount hosts file
	TARGET_DIR="/data/adb/modules/$MODULE_ID"
	if [ ! -d "$TARGET_DIR/system" ] || [ -f "$TARGET_DIR/disable" ] || [ -f "$TARGET_DIR/remove" ] ||
		[ -f "$TARGET_DIR/skip_mountify" ] || [ -f "$TARGET_DIR/system/etc/hosts" ]; then
		echo "mountify/post-fs-data: module with name $MODULE_ID not meant to be mounted" >> /dev/kmsg
		return
	fi

	echo "mountify/post-fs-data: processing $MODULE_ID" >> /dev/kmsg

	# skip_mount is not needed on .nomount MKSU - 5ec1cff/KernelSU/commit/76bfccd
	# skip_mount is also not needed for litemode APatch - bmax121/APatch/commit/7760519
	if { [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; } || { [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; }; then 
		# we can delete skip_mount if nomount / litemode
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

	# we can copy over contents of system folder only
	BASE_DIR="/data/adb/modules/$MODULE_ID/system"
	
	# copy over our files: follow symlinks, recursive, force.
	cd "$MNT_FOLDER" && cp -Lrf "$BASE_DIR"/* "$FAKE_MOUNT_NAME"

	# go inside
	cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

	# make sure to mirror selinux context
	# else we get "u:object_r:tmpfs:s0"
	for file in $( find -L $BASE_DIR | sed "s|$BASE_DIR||g" ) ; do 
		# echo "mountify_debug chcorn $BASE_DIR$file to $MNT_FOLDER/$FAKE_MOUNT_NAME$file" >> /dev/kmsg
		busybox chcon --reference="$BASE_DIR$file" "$MNT_FOLDER/$FAKE_MOUNT_NAME$file"
	done

	# catch opaque dirs, requires getfattr
	for dir in $( find -L $BASE_DIR -type d ) ; do
		if getfattr -d "$dir" | grep -q "trusted.overlay.opaque" ; then
			# echo "mountify_debug: opaque dir $dir found!" >> /dev/kmsg
			opaque_dir=$(echo "$dir" | sed "s|$BASE_DIR|.|")
			busybox setfattr -n trusted.overlay.opaque -v y "$opaque_dir"
			# echo "mountify_debug: replaced $opaque_dir!" >> /dev/kmsg
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

if [ "$decoy_mount_enabled" = "1" ] && [ -d "$DECOY_MOUNT_FOLDER" ] && [ "$(ls -A "$DECOY_MOUNT_FOLDER" 2>/dev/null | wc -l)" -eq 0 ]; then
	mount -t tmpfs tmpfs "$DECOY_MOUNT_FOLDER"
fi


if [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; then
	# create 2GB sparse
	busybox dd if=/dev/zero of="$MNT_FOLDER/mountify-ext4" bs=1M count=0 seek="$sparse_size"
	/system/bin/mkfs.ext4 -O ^has_journal "$MNT_FOLDER/mountify-ext4"
	busybox mount -o loop,rw "$MNT_FOLDER/mountify-ext4" "$MNT_FOLDER/$FAKE_MOUNT_NAME"
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

if [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; then
	# unmount, sync and remount ext4 image as ro
	busybox umount -l "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	busybox sync
	/system/bin/resize2fs -M "$MNT_FOLDER/mountify-ext4"
	
	if [ "$spoof_sparse" = "1" ] && [ -w "/apex" ] && [ ! -e "/apex/$FAKE_APEX_NAME" ]; then
		# here we copy how android does it
		mkdir -p "/apex/$FAKE_APEX_NAME@1"
		busybox mount -o loop,ro,dirsync,seclabel,nodev,noatime "$MNT_FOLDER/mountify-ext4" "/apex/$FAKE_APEX_NAME@1"
		mkdir -p "/apex/$FAKE_APEX_NAME" # then prepare the original for it
		busybox mount --bind,ro "/apex/$FAKE_APEX_NAME@1" "/apex/$FAKE_APEX_NAME"
		rm -rf "$MNT_FOLDER/$FAKE_MOUNT_NAME"
		busybox ln -sf "/apex/$FAKE_APEX_NAME" "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	else
		busybox mount -o loop,ro "$MNT_FOLDER/mountify-ext4" "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	fi

	# or another bind mount ?? this creates another mount, but hey, it werks
	# busybox mount --bind,ro "/apex/com.android.mntservice" "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	
fi

# mount 
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"
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

if [ "$decoy_mount_enabled" = "1" ] && [ -d "$DECOY_MOUNT_FOLDER" ]; then
	busybox umount -l "$DECOY_MOUNT_FOLDER"
fi

# log after
cat /proc/mounts > "$LOG_FOLDER/after"
echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
