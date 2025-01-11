#!/bin/sh
# mount.sh
# global mounting script for ap/ksu modules via overlayfs

# exit for missing args
if [ -z $1 ] || [ -z $2 ]; then
	echo "usage: "
	echo "$(basename "$0" ) module_id fake_folder_name"
	exit 1
fi

TARGET_DIR="/data/adb/modules/$1"

if [ ! -d $TARGET_DIR ]; then
	echo "module with name $1 does NOT exist?"
	exit 1
fi

if [ -f $TARGET_DIR/disable ] || [ -f $TARGET_DIR/remove ]; then
	echo "exiting since $1 is not meant to be mounted"
	exit 1
fi

FAKE_MOUNT_NAME="$2"
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
[ ! -f $TARGET_DIR/skip_mount ] && touch $TARGET_DIR/skip_mount

[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

mkdir "$MNT_FOLDER/$FAKE_MOUNT_NAME"

if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "failed creating folder with fake_folder_name $2"
	exit 1
fi

${SUSFS_BIN} add_sus_path "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# handle single depth on magic mount
single_depth() {
	for DIR in $( ls -d system/apex/ system/app/ system/bin/ system/etc/ system/fonts/ system/framework/ system/lib/ system/lib64/ system/priv-app/ system/usr/ 2>/dev/null ); do
		mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount --bind "$(pwd)/$DIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

normal_depth() {
	for DIR in $(ls -d */*/ ); do
		mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount --bind "$(pwd)/$DIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR"
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# https://github.com/5ec1cff/KernelSU/commit/92d793d0e0e80ed0e87af9e39879d2b70c37c748
# on overlayfs, moddir/system/product is symlinked to moddir/product
# on magic, moddir/product it symlinked to moddir/system/product
if [ "$KSU_MAGIC_MOUNT" = "true" ] || [ "$APATCH_BIND_MOUNT" = "true" ]; then
	# handle single depth on magic mount
	cd "$TARGET_DIR"
	single_depth
	# normal routine
	cd "$TARGET_DIR/system"
	normal_depth
else
	cd "$TARGET_DIR"
	normal_depth
fi

# EOF
