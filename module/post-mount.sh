#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"

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
	for i in $(ls -d */*/); do
		busybox mount -t overlay -o "lowerdir=/debug_ramdisk/mountify/wo/$i:/$i" overlay "/$i"
		${SUSFS_BIN} add_sus_mount "/$i"
	done
fi

# EOF
