#!/bin/sh
# post-fs-data.sh / metamount.sh
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
test_decoy_mount=0
DECOY_MOUNT_FOLDER="/oem"
mountify_expert_mode=0
enable_lkm_nuke=0
lkm_filename="nuke.ko"
# read config
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh
# exit if disabled
if [ $mountify_mounts = 0 ]; then
	exit 0
fi

# set prefix
# this is to handle it properly on kernelsu's metamodule mode
# we move this as metamount.sh on customize
DMESG_PREFIX="mountify/post-fs-data"
if [ -f "$MODDIR/metamount.sh" ]; then
	DMESG_PREFIX="mountify/metamount"
fi

# single instance run
# on ksu's metamodule mode, it seems post-fs-data runs twice
MOUNTIFY_LOCK="/dev/mountify_single_instance"
if [ -f "$MOUNTIFY_LOCK" ]; then
	echo "$DMESG_PREFIX: mountify already ran!" >> /dev/kmsg
	exit 1
fi
touch "$MOUNTIFY_LOCK"

# add simple anti bootloop logic
BOOTCOUNT=0
[ -f "$MODDIR/count.sh" ] && . "$MODDIR/count.sh"

BOOTCOUNT=$(( BOOTCOUNT + 1))

if [ ! -f "$PERSISTENT_DIR/explicit_I_want_a_bootloop" ] && [ $BOOTCOUNT -gt 1 ]; then
	touch $MODDIR/disable
	rm "$MODDIR/count.sh"
	string="description=anti-bootloop triggered. module disabled. enable to activate."
	sed -i "s/^description=.*/$string/g" $MODDIR/module.prop
	exit 1
else
	echo "BOOTCOUNT=1" > "$MODDIR/count.sh"
fi

# grab start time
echo "$DMESG_PREFIX: start!" >> /dev/kmsg

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
apex
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
my_stock
oem
optics
prism"

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
			echo "$DMESG_PREFIX: decoy folder $DECOY_MOUNT_FOLDER" >> /dev/kmsg
			decoy_mount_enabled="1"
			break
		fi
	done
fi

# functions

# controlled depth ($targets fuckery)
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	mount_success=0
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		if [ "$decoy_mount_enabled" = "1" ] && [ -w "$DECOY_MOUNT_FOLDER" ]; then
			mkdir -p "$DECOY_MOUNT_FOLDER/$2$DIR"
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$DECOY_MOUNT_FOLDER$2$DIR:$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR" && mount_success=1
		else
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR" && mount_success=1
		fi
		[ "$mount_success" = 1 ] && echo "$2$DIR" >> "$LOG_FOLDER/mountify_mount_list"
	done
}

# handle single depth (/system/bin, /system/etc, et. al)
single_depth() {
	mount_success=0
	for DIR in $( ls -d */ | sed 's/.$//'  | grep -vE "^(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		if [ "$decoy_mount_enabled" = "1" ] && [ -w "$DECOY_MOUNT_FOLDER" ]; then
			mkdir -p "$DECOY_MOUNT_FOLDER/system/$DIR"
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$DECOY_MOUNT_FOLDER/system/$DIR:$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" "/system/$DIR" && mount_success=1
		else
			busybox mount -t "$FS_TYPE_ALIAS" -o "lowerdir=$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" "/system/$DIR" && mount_success=1
		fi
		[ "$mount_success" = 1 ] && echo "/system/$DIR" >> "$LOG_FOLDER/mountify_mount_list"
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
		echo "$DMESG_PREFIX: missing arguments, fuck off" >> /dev/kmsg
		return
	fi

	MODULE_ID="$1"
	
	# return for certain modules
	# De-bloater uses dummy text, not whiteouts, which does not really work
	if [ "$MODULE_ID" = "De-bloater" ]; then
		echo "$DMESG_PREFIX: module with name $MODULE_ID is blacklisted" >> /dev/kmsg
		return
	fi

	# test for various stuff
	# you dont want to global mount hosts file
	TARGET_DIR="/data/adb/modules/$MODULE_ID"
	if [ ! -d "$TARGET_DIR/system" ] || [ -f "$TARGET_DIR/disable" ] || [ -f "$TARGET_DIR/remove" ] ||
		[ -f "$TARGET_DIR/skip_mountify" ] || [ -f "$TARGET_DIR/system/etc/hosts" ]; then
		echo "$DMESG_PREFIX: module with name $MODULE_ID not meant to be mounted" >> /dev/kmsg
		return
	fi

	# lets just add another clause for ksu metamodule mode
	# this way its easier to maintain
	# on metamodule mode, we can actually respect skip_mount
	if [ -f "$MODDIR/metamount.sh" ] && [ -f "$TARGET_DIR/skip_mount" ]; then
		echo "$DMESG_PREFIX: module with name $MODULE_ID has skip_mount" >> /dev/kmsg
		return	
	fi

	echo "$DMESG_PREFIX: processing $MODULE_ID" >> /dev/kmsg

	# skip_mount is not needed on .nomount MKSU - 5ec1cff/KernelSU/commit/76bfccd
	# skip_mount is also not needed for litemode APatch - bmax121/APatch/commit/7760519
	if { [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; } || 
		{ [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; } || 
		[ -f "$MODDIR/metamount.sh" ]; then 
		
		# ^ HACK: the metamodule check is here just so it wont create a skip_mount flag.
		# we do NOT have 'goto' in shell so we to keep it this way.
		# since we already check it above, it should NOT be here!

		# we can delete skip_mount if nomount / litemode
		[ -f "$TARGET_DIR/skip_mount" ] && rm "$TARGET_DIR/skip_mount"
		[ -f "$PERSISTENT_DIR/skipped_modules" ] && rm "$PERSISTENT_DIR/skipped_modules"
	else
		if [ ! -f "$TARGET_DIR/skip_mount" ]; then
			touch "$TARGET_DIR/skip_mount"
			# log modules that got skip_mounted
			# we can likely clean those at uninstall
			echo "$MODULE_ID" >> $PERSISTENT_DIR/skipped_modules
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

# this way only sparse mode on ksu gets the rule
handle_ksu_sepolicy() {
	busybox chcon "u:object_r:ksu_file:s0" "$MNT_FOLDER/mountify-ext4"
}

# prevent this fuckup since on expert mode this isnt checked
if [ "$FAKE_MOUNT_NAME" = "persist" ]; then
	echo "$DMESG_PREFIX: folder name named $FAKE_MOUNT_NAME is not allowed!" >> /dev/kmsg
	exit 1
fi

# make sure its not there
if [ ! "$mountify_expert_mode" = 1 ] && [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# anti fuckup
	# this is important as someone might actually use legit folder names
	# and same shit exists on MNT_FOLDER, prevent this issue.
	echo "$DMESG_PREFIX: exiting since fake folder name $FAKE_MOUNT_NAME already exists!" >> /dev/kmsg
	exit 1
fi

# create it
mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"
if [ ! -f "$MODDIR/no_tmpfs_xattr" ] && [ ! "$use_ext4_sparse" = "1" ]; then
	echo "$DMESG_PREFIX: mounting $(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")" >> /dev/kmsg
	busybox mount -t tmpfs tmpfs "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
fi
touch "$MNT_FOLDER/$FAKE_MOUNT_NAME/placeholder"

# then make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	# weird if it happens
	echo "$DMESG_PREFIX: failed creating folder with fake_folder_name $FAKE_MOUNT_NAME !" >> /dev/kmsg
	exit 1
fi

if [ "$decoy_mount_enabled" = "1" ] && [ -d "$DECOY_MOUNT_FOLDER" ] && [ "$(ls -A "$DECOY_MOUNT_FOLDER" 2>/dev/null | wc -l)" -eq 0 ]; then
	echo "$DMESG_PREFIX: mounting $DECOY_MOUNT_FOLDER" >> /dev/kmsg
	mount -t tmpfs tmpfs "$DECOY_MOUNT_FOLDER"
fi

if [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; then
	# create 2GB sparse
	busybox dd if=/dev/zero of="$MNT_FOLDER/mountify-ext4" bs=1M count=0 seek="$sparse_size"
	/system/bin/mkfs.ext4 -O ^has_journal "$MNT_FOLDER/mountify-ext4"

	# https://github.com/tiann/KernelSU/pull/3019
	[ "$KSU" = "true" ] && handle_ksu_sepolicy

	busybox mount -o loop,rw "$MNT_FOLDER/mountify-ext4" "$MNT_FOLDER/$FAKE_MOUNT_NAME"
fi

# if manual mode and modules.txt has contents
if [ $mountify_mounts = 1 ] && grep -qv "#" "$PERSISTENT_DIR/modules.txt" >/dev/null 2>&1 ; then
	# manual mode
	for line in $( sed '/#/d' "$PERSISTENT_DIR/modules.txt" ); do
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
	echo "$DMESG_PREFIX: unmounting $DECOY_MOUNT_FOLDER" >> /dev/kmsg
	busybox umount -l "$DECOY_MOUNT_FOLDER"
fi

if [ ! -f "$MODDIR/no_tmpfs_xattr" ] && [ ! "$use_ext4_sparse" = "1" ]; then
	echo "$DMESG_PREFIX: unmounting $(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")" >> /dev/kmsg
	busybox umount -l "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
fi

# insmod compat - system provided insmod most of the times is betterer
if command -v /system/bin/insmod > /dev/null 2>&1; then
	insmod() { /system/bin/insmod "$@"; }
else
	insmod() { busybox insmod "$@"; }
fi

# nuke ext4 sysfs
# this unregisters an ext4 node used on ext4 mode (duh)
# this way theres no nodes are lingering on /proc/fs
if [ ! -f "$MODDIR/ksud_has_nuke_ext4" ] && [ $enable_lkm_nuke = 1 ] && [ -f "$MODDIR/lkm/$lkm_filename" ] && 
	{ [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; } && 
	[ "$spoof_sparse" = "0" ]; then	
	
	mnt="$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
	kptr_set=$(cat /proc/sys/kernel/kptr_restrict)
	echo 1 > /proc/sys/kernel/kptr_restrict
	ptr_address=$(grep " ext4_unregister_sysfs$" /proc/kallsyms | awk {'print "0x"$1'})
	echo "$DMESG_PREFIX: loading LKM with mount_point=$mnt symaddr=$ptr_address" >> /dev/kmsg
	insmod "$MODDIR/lkm/$lkm_filename" mount_point="$mnt" symaddr="$ptr_address" > /dev/null 2>&1
	echo $kptr_set > /proc/sys/kernel/kptr_restrict
	echo "$DMESG_PREFIX: unmounting $mnt" >> /dev/kmsg
	busybox umount -l "$mnt"

fi

# ksud kernel nuke-ext4-sysfs
# uses official ksud interface
if [ -f "$MODDIR/ksud_has_nuke_ext4" ] && [ "$spoof_sparse" = "0" ] &&
	{ [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; }; then

	mnt="$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"
	echo "$DMESG_PREFIX: ksud kernel nuke-ext4-sysfs $mnt" >> /dev/kmsg
	/data/adb/ksud kernel nuke-ext4-sysfs "$mnt"
	echo "$DMESG_PREFIX: unmounting $mnt" >> /dev/kmsg
	busybox umount -l "$mnt"

fi

# delete the sparse
if [ -f "$MODDIR/no_tmpfs_xattr" ] || [ "$use_ext4_sparse" = "1" ]; then
	[ -f "$MNT_FOLDER/mountify-ext4" ] && rm "$MNT_FOLDER/mountify-ext4"
fi

# log after
cat /proc/mounts > "$LOG_FOLDER/after"
echo "$DMESG_PREFIX: finished!" >> /dev/kmsg

# EOF
