#!/bin/sh
# whiteout.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"
FAKE_MOUNT_NAME="whiteouts"
mountify_whiteouts=0
# read config
. $MODDIR/config.sh
# exit if disabled
if [ $mountify_whiteouts = 0 ]; then
	exit 0
fi

# functions
# whiteout_create
whiteout_create() {
	mkdir -p "/debug_ramdisk/mountify/wo/${1%/*}"
  	busybox mknod "/debug_ramdisk/mountify/wo/$1" c 0 0
  	busybox chcon --reference="$1" "/debug_ramdisk/mountify/wo/$1"  
  	busybox setfattr -n trusted.overlay.whiteout -v y "/debug_ramdisk/mountify/wo/$1"
  	chmod 644 "/debug_ramdisk/mountify/wo/$1"
}

for line in $( sed '/#/d' "$MODDIR/whiteouts.txt" ); do
	# make sure to only whiteout if file exists
	if [ -e "$line" ]; then
		echo "mountify/whiteout: whiting-out $line " >> /dev/kmsg
		whiteout_create "$line"
	fi
done

# here we do the vendor mount mimic
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# make sure its not there
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "mountify/whiteout: fake folder with name $FAKE_MOUNT_NAME already exists!" >> /dev/kmsg
	exit 1
fi

# create it
cd "$MNT_FOLDER" && cp -r "/debug_ramdisk/mountify/wo" "$FAKE_MOUNT_NAME"

# then make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "mountify/whiteout: failed creating folder with fake_folder_name $FAKE_MOUNT_NAME" >> /dev/kmsg
	exit 1
fi

cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"

for file in $( find ./ | sed "s|./|/|") ; do 
	busybox chcon --reference="/debug_ramdisk/mountify/wo/$file" ".$file"  
done

echo "mountify/whiteout: mounting whiteouts" >> /dev/kmsg
for DIR in $(ls -d */); do
	busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
	${SUSFS_BIN} add_sus_mount "/$DIR"
done

# EOF
