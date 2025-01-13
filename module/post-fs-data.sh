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

# --
# module mount section
# modules.txt
# <modid> <fake_folder_name>
IFS="
"
for line in $( sed '/#/d' "$MODDIR/modules.txt" ); do
	module_id=$( echo $line | awk {'print $1'} )
	sh "$MODDIR/mount.sh" "$module_id"
done

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
