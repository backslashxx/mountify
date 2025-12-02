#!/bin/sh
# customize.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

# warn adventurous people
WARNING_STRING="WARNING: this file is part of mountify's autoconfiguration! DO NOT DELETE."

# some bullshit just to use clear
if [ "$MMRL" = "true" ] || { [ "$KSU" = "true" ] && [ "$KSU_VER_CODE" -ge 11998 ]; } || 
	{ [ "$KSU_NEXT" = "true" ] && [ "$KSU_VER_CODE" -ge 12144 ]; } ||
	{ [ "$APATCH" = "true" ] && [ "$APATCH_VER_CODE" -ge 11022 ]; }; then
	clear
        loops=20
        while [ $loops -gt 1 ];  do 
		for i in '[-]' '[/]' '[|]' '[\]'; do 
		        echo "$i"
		        sleep 0.1
		        clear
		        loops=$((loops - 1)) 
		done
        done
else
	# sleep a bit to make it look like something is happening!!
	sleep 2
fi

# routine start
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

test_ext4_image() {
	mkdir -p "$MNT_FOLDER/mountify-mount-test"
	busybox dd if=/dev/zero of="$MNT_FOLDER/mountify-ext4-test" bs=1M count=0 seek=8 >/dev/null 2>&1 || ext4_fail=1
	/system/bin/mkfs.ext4 -O ^has_journal "$MNT_FOLDER/mountify-ext4-test" >/dev/null 2>&1 || ext4_fail=1
	busybox mount -o loop,rw "$MNT_FOLDER/mountify-ext4-test" "$MNT_FOLDER/mountify-mount-test" >/dev/null 2>&1 || ext4_fail=1
	busybox umount -l "$MNT_FOLDER/mountify-mount-test" || ext4_fail=1

	# cleanup
	rm -rf "$MNT_FOLDER/mountify-ext4-test" "$MNT_FOLDER/mountify-mount-test"
	
	if [ "$ext4_fail" = "1" ]; then
		abort "[!] ext4 fallback mode test fail!"
	fi
}

echo "[+] mountify"
echo "[+] SysReq test"

# test for overlayfs
if grep -q "overlay" /proc/filesystems > /dev/null 2>&1; then \
	echo "[+] CONFIG_OVERLAY_FS"
	echo "[+] overlay found in /proc/filesystems"
else
	abort "[!] CONFIG_OVERLAY_FS is required for this module!"
fi

# test for tmpfs xattr

testfile="$MNT_FOLDER/tmpfs_xattr_testfile"
rm "$testfile" > /dev/null 2>&1 
busybox mknod "$testfile" c 0 0 > /dev/null 2>&1 
if busybox setfattr -n trusted.overlay.whiteout -v y "$testfile" > /dev/null 2>&1 ; then 
	echo "[+] CONFIG_TMPFS_XATTR"
	echo "[+] tmpfs extended attribute test passed"
	rm "$testfile" > /dev/null 2>&1 
else
	rm "$testfile" > /dev/null 2>&1 
	echo "[!] CONFIG_TMPFS_XATTR fail!"
	echo "[+] testing for ext4 sparse image fallback mode"
	# check for tools
	if [ -f "/system/bin/mkfs.ext4" ] && [ -f "/system/bin/resize2fs" ]; then		
		test_ext4_image
		echo "$WARNING_STRING" > "$MODPATH/no_tmpfs_xattr"
		echo "[+] ext4 sparse fallback mode enabled"
	else
		abort "[!] tools not found, bail out."
	fi
fi

# grab version code
module_prop="/data/adb/modules/mountify/module.prop"
if [ -f $module_prop ]; then
	mountify_versionCode=$(grep versionCode $module_prop | sed 's/versionCode=//g' )
else
	mountify_versionCode=0
fi

PERSISTENT_DIR="/data/adb/mountify"
[ ! -d $PERSISTENT_DIR ] && mkdir -p $PERSISTENT_DIR


# full migration if 166+
if [ "$mountify_versionCode" -lt 166 ]; then
	echo "[!] using fresh config.sh"
	cat "$MODPATH/config.sh" > "$PERSISTENT_DIR/config.sh"
fi

configs="modules.txt whiteouts.txt config.sh"

for file in $configs; do
	if [ ! -f "$PERSISTENT_DIR/$file" ]; then
		echo "[+] moving $file"
		cat "$MODPATH/$file" > "$PERSISTENT_DIR/$file"
	fi
done

# give exec to whiteout_gen.sh
chmod +x "$MODPATH/whiteout_gen.sh"

# warn on OverlayFS managers
# while this is supported (half-assed), this is not a recommended configuration
if { [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ] &&  [ "$KSU_VER_CODE" -lt 22098 ]; } || { [ "$APATCH" = true ] && [ ! "$APATCH_BIND_MOUNT" = true ]; }; then
	printf "\n\n"
	echo "[!] ERROR: Root manager is on sparse-backed overlayfs!"
	echo "[!] This setup can cause issues and is NOT recommended."
	echo "[!] modify customize.sh to force installation!"
	abort "[!] Installation aborted!"
	# ^ just change abort to echo or something
fi

SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"
SUSFS_VERSION="$( ${SUSFS_BIN} show version | head -n1 | sed 's/v//; s/\.//g' )"
if [ "$KSU" = true ] && [ -f ${SUSFS_BIN} ] && { [ "$SUSFS_VERSION" -eq 1510 ] || [ "$SUSFS_VERSION" -eq 1511 ]; }; then
	printf "\n\n"
	echo "[!] ERROR: Mountify causes conflicts with this susfs version."
	echo "[!] This setup can cause issues and is NOT recommended."
	echo "[!] modify customize.sh to force installation!"
	abort "[!] Installation aborted!"
	# ^ just change abort to echo or something
fi

# ahemm
if [ -f "$PERSISTENT_DIR/explicit_I_want_symlink" ]; then
	echo "[!] forcing symlink script as post-fs-data!"
	cat "$MODPATH/symlink/mountify-symlink.sh" > "$MODPATH/post-fs-data.sh"
fi

# workaround for awry versioning on KernelSU forks
# we cannot rely on just ksu vercode
if [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ] && [ "$KSU_VER_CODE" -ge 22098 ] && 
	( grep -q "metamodule=true" $MODPATH/module.prop >/dev/null 2>&1 || grep -q "metamodule=1" $MODPATH/module.prop >/dev/null 2>&1 ); then
	echo "[+] mountify will be installed in metamodule mode!"
	mv "$MODPATH/post-fs-data.sh" "$MODPATH/metamount.sh"
fi

# since even mm ksud can have this feature, we check this and add a flag that we can check
if [ "$KSU" = true ] && /data/adb/ksud kernel 2>&1 | grep -q "nuke-ext4-sysfs" >/dev/null 2>&1; then
	echo "$WARNING_STRING" > "$MODPATH/ksud_has_nuke_ext4"
fi

rm -rf "$MODPATH/symlink"
rm "$MODPATH/modules.txt"
rm "$MODPATH/whiteouts.txt"
rm "$MODPATH/config.sh"

# EOF
