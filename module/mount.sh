#!/bin/sh
# mount.sh
# tmpfs edition
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs

# exit for missing args
if [ -z "$1" ] || [ -z "$2" ]; then
	echo "usage: "
	echo "$(basename "$0" ) module_id fake_folder_name"
	exit 1
fi

MODULE_ID="$1"
FAKE_MOUNT_NAME="$2"

TARGET_DIR="/data/adb/modules/$MODULE_ID"
if [ ! -d "$TARGET_DIR" ] || [ -f "$TARGET_DIR/disable" ] || [ -f "$TARGET_DIR/remove" ]; then
	echo "module with name $MODULE_ID does NOT exist or not meant to be mounted"
	exit 1
fi

# dont forget to skip_mount
[ ! -f "$TARGET_DIR/skip_mount" ] && touch "$TARGET_DIR/skip_mount"

# create our folder, get in, copy everything, get in
mkdir -p /debug_ramdisk/mountify
cd /debug_ramdisk/mountify && cp -r "/data/adb/modules/$MODULE_ID" "$MODULE_ID" && cd "/debug_ramdisk/mountify/$MODULE_ID"

# make sure to mirror selinux context
# else we get "u:object_r:tmpfs:s0"
IFS="
"
for file in $( find ./ | sed "s|./|/|") ; do 
	busybox chcon --reference="/data/adb/modules/$MODULE_ID/$file" ".$file"  
done

# here we do the vendor mount mimic
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

mkdir -p "$MNT_FOLDER/$FAKE_MOUNT_NAME"

if [ ! -d "$MNT_FOLDER/$FAKE_MOUNT_NAME" ]; then
	echo "failed creating folder with fake_folder_name $FAKE_MOUNT_NAME"
	exit 1
fi

busybox mount --bind "$(pwd)/$DIR" "$MNT_FOLDER/$FAKE_MOUNT_NAME"

# mounting functions
normal_depth() {
	for DIR in $(ls -d */*/); do
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# handle single depth on magic mount
single_depth() {
	for DIR in $( ls -d system/apex/ system/app/ system/bin/ system/etc/ system/fonts/ system/framework/ system/lib/ system/lib64/ system/priv-app/ system/usr/ 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$MNT_FOLDER/$FAKE_MOUNT_NAME/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "/$DIR"
	done
}

# https://github.com/5ec1cff/KernelSU/commit/92d793d0e0e80ed0e87af9e39879d2b70c37c748
# on overlayfs, moddir/system/product is symlinked to moddir/product
# on magic, moddir/product it symlinked to moddir/system/product
if [ "$KSU_MAGIC_MOUNT" = "true" ] || [ "$APATCH_BIND_MOUNT" = "true" ]; then
	# handle single depth on magic mount
	single_depth
	# normal routine
	cd system && normal_depth
else
	normal_depth
fi

# EOF
