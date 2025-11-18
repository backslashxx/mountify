#!/bin/sh
# global_mount.sh
# mountify standalone script
# you can put or execute this on post-fs-data.sh or service.sh of a module.
# testing for overlayfs and tmpfs_xattr is on test-sysreq.sh
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="${0%/*}"

# you can mimic vendor mounts like, my_bigball, vendor_dklm, mi_ext
# whatever. use what you want. provided here is just an example
FAKE_MOUNT_NAME="mountify_1"

# mount device name
# you can use APatch, KSU or magisk here to let a zygisk provider unmount
# otherwise, just use "overlay" as default
MOUNT_DEVICE_NAME="overlay"

# you can also use random characters whatever, but this might be a bad meme
# as we are trying to mimic a vendor mount, but its here if you want
# uncomment to use
# FAKE_MOUNT_NAME="$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)"

SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
KSUD_BIN=/data/adb/ksud
# kernel umount is not needed but you can tweak it here if you want to
# set to 0 to disable
# set to 1 for susfs4ksu
# set to 2 for ksud kernel umount
mountify_kernel_umount=0

# separate shit with lines
IFS="
"

# targets for specially handled mounts
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

# functions

# controlled depth ($targets fuckery)
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:$2$DIR" "$MOUNT_DEVICE_NAME" "$2$DIR"
		[ $mountify_kernel_umount = 1 ] && ${SUSFS_BIN} add_try_umount "$2$DIR" 1 > /dev/null 2>&1
		[ $mountify_kernel_umount = 2 ] && ${KSUD_BIN} kernel umount add "$2$DIR" --flags 2 > /dev/null 2>&1
	done
}

# handle single depth (/system/bin, /system/etc, et. al)
single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//' | grep -vE "(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/system/$DIR" "$MOUNT_DEVICE_NAME" "/system/$DIR"
		[ $mountify_kernel_umount = 1 ] && ${SUSFS_BIN} add_try_umount "/system/$DIR" 1 > /dev/null 2>&1
		[ $mountify_kernel_umount = 2 ] && ${KSUD_BIN} kernel umount add "/system/$DIR" --flags 2 > /dev/null 2>&1
	done
}

# getfattr compat
if /system/bin/getfattr -d /system/bin > /dev/null 2>&1; then
	getfattr() { /system/bin/getfattr "$@"; }
else
	getfattr() { /system/bin/toybox getfattr "$@"; }
fi

# routine start
echo "mountify/standalone: start!" >> /dev/kmsg

# make sure $MODDIR/skip_mount exists!
# this way manager won't mount it
# as we handle the mounting ourselves
[ ! -f $MODDIR/skip_mount ] && touch $MODDIR/skip_mount
# mountify 131 added this
# this way mountify wont remount this module
[ ! -f $MODDIR/skip_mountify ] && touch $MODDIR/skip_mountify

# this is a fast lookup for a writable dir
# these tends to be always available
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# folder hierarchy prep
# undo_handle_partition
# because ksu moves them e.g. MODDIR/system/product to MODDIR/product
# this undoes that
undo_handle_partition() {
	partition_to_undo="$1"
	if [ -L "$MODDIR/system/$partition_to_undo" ] && [ -d "$MODDIR/$partition_to_undo" ]; then
		rm -f "$MODDIR/system/$partition_to_undo"
		mv -f "$MODDIR/$partition_to_undo" "$MODDIR/system/$partition_to_undo"
	fi
}

undo_handle_partition vendor
undo_handle_partition product
undo_handle_partition system_ext
undo_handle_partition odm

# make sure fake_mount name does not exist
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then 
	echo "mountify/standalone: folder with name $FAKE_MOUNT_NAME already exists!" >> /dev/kmsg
	exit 1
fi

# create our folder
mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# mount our own tmpfs
echo "mountify/standalone: mounting $(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")" >> /dev/kmsg
busybox mount -t tmpfs tmpfs "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"

# then we make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "standalone lol exit"
	exit 1
fi

# create placeholder
touch "$MNT_FOLDER/$FAKE_MOUNT_NAME/placeholder"

# our base directory on magic mount
BASE_DIR="$MODDIR/system"

# copy over our files: follow symlinks, recursive, force.
echo "mountify/standalone: processing $MODDIR" >> /dev/kmsg
cp -Lrf "$BASE_DIR"/* "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# go inside
cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# here we mirror selinux context, if we dont, we get "u:object_r:tmpfs:s0"
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

# now here we mount
# handle single depth
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

# unmount the tmpfs we created
echo "mountify/standalone: unmounting $(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")" >> /dev/kmsg
busybox umount -l "$(realpath "$MNT_FOLDER/$FAKE_MOUNT_NAME")"

# EOF
