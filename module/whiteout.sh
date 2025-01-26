#!/bin/sh
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

# here we do the vendor mount mimic
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

# make sure its not there
if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "mountify/whiteout: fake folder with name $FAKE_MOUNT_NAME already exists!" >> /dev/kmsg
	exit 1
fi

# create it
mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# then make sure its there
if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "mountify/whiteout: failed creating folder with fake_folder_name $FAKE_MOUNT_NAME" >> /dev/kmsg
	exit 1
fi

# functions
# whiteout_create
whiteout_create() {
	mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME/${1%/*}"
  	busybox mknod "$MNT_FOLDER/$FAKE_MOUNT_NAME/$1" c 0 0
  	busybox setfattr -n trusted.overlay.whiteout -v y "$MNT_FOLDER/$FAKE_MOUNT_NAME/$1"
  	chmod 644 "$MNT_FOLDER/$FAKE_MOUNT_NAME/$1"
}

for line in $( sed '/#/d' "$MODDIR/whiteouts.txt" ); do
	whiteout_create "$line"
done

if [ -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "mountify/whiteout: processing whiteouts" >> /dev/kmsg
	cd "$MNT_FOLDER/$FAKE_MOUNT_NAME"
	for DIR in $(ls -d */*/); do
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
fi

# EOF
