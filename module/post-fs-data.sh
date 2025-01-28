#!/bin/sh
# post-fs-data.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"
. $MODDIR/config.sh

# grab start time
echo "mountify/post-fs-data: start!" >> /dev/kmsg

# module mount section
# modules.txt
# <modid> <fake_folder_name>
IFS="
"
for line in $( sed '/#/d' "$MODDIR/modules.txt" ); do
	module_id=$( echo $line | awk {'print $1'} )
	folder_name=$( echo $line | awk {'print $2'} )
	sh "$MODDIR/mount.sh" "$module_id" "$folder_name"
done


[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# whiteout /system/addon.d
# everything else can be handled like a module but not this, due 
# to it being single depth. we can treat this as special case.
whiteout_addond() {
	if [ ! -e /system/addon.d ] || [ ! "$mountify_whiteout_addond" = 1 ] || [ -z "$FAKE_ADDOND_MOUNT_NAME" ]; then
		return
	fi
	echo "mountify/post-fs-data: whiteout_addond routine start! " >> /dev/kmsg
	# whiteout routine
	addond_mount_point="$MNT_FOLDER/$FAKE_ADDOND_MOUNT_NAME/system"
	mkdir -p "$addond_mount_point"
	busybox chcon --reference="/system" "$addond_mount_point" 
	busybox mknod "$addond_mount_point/addon.d" c 0 0
	busybox chcon --reference="/system/addon.d" "$addond_mount_point/addon.d" 
	busybox setfattr -n trusted.overlay.whiteout -v y "$addond_mount_point/addon.d"
	chmod 644 "$addond_mount_point/addon.d"
	
	# mount
	busybox mount -t overlay -o "lowerdir=$addond_mount_point:/system" overlay "/system"
	[ ! -e /system/addon.d ] && echo "mountify/post-fs-data: whiteout_addond success!" >> /dev/kmsg
}

whiteout_addond

echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
