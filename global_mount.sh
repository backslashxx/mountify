#!/bin/sh
# global mounting script for ap/ksu
# This is free software, released under The Unlicense.
MODDIR="${0%/*}"
# you can mimic vendor mounts like, my_bigball, vendor_dklm, mi_ext
# whatever use what you want provided here is just an example
modid="my_ringtone"
# susfs usage is optional currently but heres how you can utilize it
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs

# make sure $MODDIR/skip_mount exists!
# this way ksu wont mount it
# we handle the mounting ourselves
[ ! -f $MODDIR/skip_mount ] && touch $MODDIR/skip_mount

# this is a fast lookup for a writable dir
# these tends to be always available
[ -w /mnt ] && basefolder=/mnt
[ -w /mnt/vendor ] && basefolder=/mnt/vendor

mkdir $basefolder/$modid
${SUSFS_BIN} add_sus_path $basefolder/$modid

# https://github.com/5ec1cff/KernelSU/commit/92d793d0e0e80ed0e87af9e39879d2b70c37c748
# on overlayfs, moddir/system/product is symlinked to moddir/product
# on magic, moddir/product it symlinked to moddir/system/product
BASE_DIR=$MODDIR
if [ "$KSU_MAGIC_MOUNT" = "true" ] || [ "$APATCH_BIND_MOUNT" = "true" ]; then
	BASE_DIR="$MODDIR/system"
fi
cd $BASE_DIR

# remove symlinks, remove system/product -> ../product shit
# this is optional
# find ./ -maxdepth 2 -type l -delete

for i in $(ls -d */*); do
	mkdir -p $basefolder/$modid/$i
	mount --bind $BASE_DIR/$i $basefolder/$modid/$i
	mount -t overlay -o "lowerdir=$basefolder/$modid/$i:/$i" overlay /$i
	${SUSFS_BIN} add_sus_mount /$i
done
