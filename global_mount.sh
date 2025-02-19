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
FAKE_MOUNT_NAME="my_bullshit"

# you can also use random characters whatever, but this might be a bad meme
# as we are trying to mimic a vendor mount, but its here if you want
# uncomment to use
# FAKE_MOUNT_NAME="$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)"

# susfs usage is not required but we can use it if its there.
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
# set to 1 to enable
mountify_use_susfs=0

# separate shit with lines
IFS="
"

# targets for specially handled mounts
targets="odm
product
system_ext
vendor"

# functions

# controlled depth ($targets fuckery)
controlled_depth() {
	if [ -z "$1" ] || [ -z "$2" ]; then return ; fi
	for DIR in $(ls -d $1/*/ | sed 's/.$//' ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:$2$DIR" overlay "$2$DIR"
		[ $mountify_use_susfs = 1 ] && ${SUSFS_BIN} add_sus_mount "$2$DIR"
	done
}

# handle single depth (/system/bin, /system/etc, et. al)
single_depth() {
	for DIR in $( ls -d */ | sed 's/.$//' | grep -vE "(odm|product|system_ext|vendor)$" 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/system/$DIR" overlay "/system/$DIR"
		[ $mountify_use_susfs = 1 ] && ${SUSFS_BIN} add_sus_mount "/system/$DIR"
	done
}

# getfattr compat
if /system/bin/getfattr -d /system/bin > /dev/null 2>&1; then
	getfattr() { /system/bin/getfattr "$@"; }
else
	getfattr() { /system/bin/toybox getfattr "$@"; }
fi

# routine start

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

# make sure fake_mount name does not exist
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then 
	exit 1
fi


BASE_DIR="$MODDIR/system"

# copy it
cd "$MNT_FOLDER" && cp -Lrf "$BASE_DIR" "$FAKE_MOUNT_NAME"

# then we make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "standalone lol exit"
	exit 1
fi

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


# EOF
