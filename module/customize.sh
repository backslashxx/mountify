#!/bin/sh
# customize.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

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
		busybox touch "$MODPATH/no_tmpfs_xattr"
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

# full migration if 154+
if [ "$mountify_versionCode" -ge 155 ]; then
	configs="modules.txt whiteouts.txt config.sh skipped_modules after-post-fs-data.sh"
else
	echo "[!] using fresh config.sh"
	configs="modules.txt whiteouts.txt skipped_modules"
fi

for file in $configs; do
	if [ -f "/data/adb/modules/mountify/$file" ]; then
		echo "[+] migrating $file"
		cat "/data/adb/modules/mountify/$file" > "$MODPATH/$file"
	fi
done

# Remove old config symlink and now webui will read and edit config directly from modules_update/mountify/config.sh before reboot
rm -f "/data/adb/modules/mountify/webroot/config.sh"

# give exec to whiteout_gen.sh
chmod +x "$MODPATH/whiteout_gen.sh"

# warn on OverlayFS managers
# while this is supported (half-assed), this is not a recommended configuration
if { [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ]; } || { [ "$APATCH" = true ] && [ ! "$APATCH_BIND_MOUNT" = true ]; }; then
	printf "\n\n"
	echo "[!] ERROR: Root manager is NOT on magic mount."
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

# EOF
