#!/bin/sh
# mount.sh
# tmpfs edition
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

# exit for missing args
if [ -z $1 ]; then
	echo "usage: "
	echo "$(basename "$0" ) module_id"
	exit 1
fi

TARGET_DIR="/data/adb/modules/$1"
if [ ! -d $TARGET_DIR ] || [ -f $TARGET_DIR/disable ] || [ -f $TARGET_DIR/remove ]; then
	echo "module with name $1 does NOT exist or not meant to be mounted"
	exit 1
fi
# dont forget to skip_mount
[ ! -f $TARGET_DIR/skip_mount ] && touch $TARGET_DIR/skip_mount

# create our folder, get in, copy everything, get in
mkdir -p /debug_ramdisk/mountify
cd /debug_ramdisk/mountify && cp -r /data/adb/modules/$1 $1 && cd /debug_ramdisk/mountify/$1

# make sure to mirror selinux context
# else we get "u:object_r:tmpfs:s0"
IFS="
"
for file in $( find ./ | sed "s|./|/|") ; do 
	busybox chcon --reference="/data/adb/modules/$1/$file" ".$file"  
done

# mounting functions
normal_depth() {
	for DIR in $(ls -d */*/); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "$DIR"
	done
}

# handle single depth on magic mount
single_depth() {
	for DIR in $( ls -d system/apex/ system/app/ system/bin/ system/etc/ system/fonts/ system/framework/ system/lib/ system/lib64/ system/priv-app/ system/usr/ 2>/dev/null ); do
		busybox mount -t overlay -o "lowerdir=$(pwd)/$DIR:/$DIR" overlay "/$DIR"
		${SUSFS_BIN} add_sus_mount "$DIR"
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
