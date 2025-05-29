#!/bin/sh
# standalone global mounting script, KernelSU OverlayFS version.
# you can put or execute this on post-fs-data.sh of a module.
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="${0%/*}"

# you can mimic vendor mounts like, my_bigball, vendor_dklm, mi_ext
# whatever. use what you want. provided here is just an example
FAKE_MOUNT_NAME="my_bullshit"

[ ! -f $MODDIR/skip_mount ] && touch $MODDIR/skip_mount
[ ! -f $MODDIR/skip_mountify ] && touch $MODDIR/skip_mountify

# this is a fast lookup for a writable dir
# these tends to be always available
[ -w /mnt ] && basefolder=/mnt
[ -w /mnt/vendor ] && basefolder=/mnt/vendor

# here we create the symlink
busybox ln -sf "$MODDIR" "$basefolder/$FAKE_MOUNT_NAME"

# now we use the symlink as upperdir
if [ -d "$basefolder/$FAKE_MOUNT_NAME" ]; then
	cd "$basefolder/$FAKE_MOUNT_NAME"
	for DIR in vendor/* product/* system_ext/* odm/* ; do
		busybox mount -t overlay -o "lowerdir=$basefolder/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay /$DIR
	done
fi

# handle system in a special way since ksu creates symlinks inside
if [ -d "$basefolder/$FAKE_MOUNT_NAME/system" ]; then
	cd "$basefolder/$FAKE_MOUNT_NAME/system"
	for DIR in $(ls -d */ | sed 's/.$//' ); do
		# only mount if its NOT a symlink
		[ ! -L $DIR ] && busybox mount -t overlay -o "lowerdir=$basefolder/$FAKE_MOUNT_NAME/system/$DIR:/system/$DIR" overlay /system/$DIR
	done
fi

# EOF
