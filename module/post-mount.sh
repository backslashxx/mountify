#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"
FAKE_MOUNT_NAME="my_super"

# here we do the vendor mount mimic
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor
mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# functions
# whiteout_create
whiteout_create() {
	mkdir -p "/debug_ramdisk/mountify/wo/${1%/*}"
  	busybox mknod "/debug_ramdisk/mountify/wo/$1" c 0 0
  	busybox setfattr -n trusted.overlay.whiteout -v y "/debug_ramdisk/mountify/wo/$1"
  	chmod 644 "/debug_ramdisk/mountify/wo/$1"
}

for line in $( sed '/#/d' "$MODDIR/whiteouts.txt" ); do
	whiteout_create "$line"
done

if [ -d /debug_ramdisk/mountify/wo ]; then
	cd /debug_ramdisk/mountify/wo
	for DIR in $(ls -d */*/); do
		mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount --bind "$(pwd)/$DIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
fi

# EOF
