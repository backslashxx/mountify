#!/bin/sh
# customize.sh
# system requirement test for mountify (symlink ver)
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
	sleep 1
fi

# routine start
echo "[+] mountify (symlink ver)"
echo "[+] SysReq test"
printf "\n\n"

## test for overlayfs
if grep -q "overlay" /proc/filesystems > /dev/null 2>&1; then \
	echo "[+] CONFIG_OVERLAY_FS"
	echo "[+] overlay found in /proc/filesystems"
else
	abort "[!] CONFIG_OVERLAY_FS is required for this module!"
fi

## test for casefolding

# standard sanity checks
if [ ! -d /data/adb/modules ]; then
	abort "[?] no /data/adb/modules"
fi

# create this folder
TEST_FOLDER="/data/adb/modules/mountify_casefold_test"

[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"
mkdir -p "$TEST_FOLDER" || abort "[x] cant create test folder"

# create files
echo "CASEFOLD_TEST_UPPERCASE" > "$TEST_FOLDER/CASEFOLD"
echo "casefold_test_lowercase" > "$TEST_FOLDER/casefold"

if [ -f "$TEST_FOLDER/CASEFOLD" ] && [ -f "$TEST_FOLDER/casefold" ]; then
	# casefold test
	if busybox diff -q "$TEST_FOLDER/CASEFOLD" "$TEST_FOLDER/casefold" >/dev/null 2>&1; then
		# both files exist, but resolves to same inode, casefolded
		[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"
		abort "[x] testfiles resolve to same inode, case-insensitive/casefolded"
	else
		# different contents — true case-sensitive FS
		echo "[+] /data/adb/modules is case-sensitive + non-casefolded"
	fi
else
	# files cant coexist, case-insensitive
	[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"
	abort "[x] testfiles cannot coexist, case-insensitive/casefolded"
fi

## test mount
busybox chcon --reference="/system" "$TEST_FOLDER"
busybox chcon --reference="/system" "$TEST_FOLDER/CASEFOLD"
busybox chcon --reference="/system" "$TEST_FOLDER/casefold"

if busybox mount -t overlay -o lowerdir="$TEST_FOLDER:/system/app" overlay "/system/app" >/dev/null 2>&1; then
	echo "[+] mount test success!"
	umount -l /system/app
else
	[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"
	abort "[x] mount test fail!!"
fi

[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"

# migrate config
configs="modules.txt whiteouts.txt config.sh skipped_modules"
for file in $configs; do
	if [ -f "/data/adb/modules/mountify/$file" ]; then
		echo "[+] migrating $file"
		cat "/data/adb/modules/mountify/$file" > "$MODPATH/$file"
	fi
done

# workaround for awry versioning on KernelSU forks
# we cannot rely on just ksu vercode
if [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ] && [ "$KSU_VER_CODE" -ge 22098 ] && 
	( grep -q "metamodule=true" $MODPATH/module.prop >/dev/null 2>&1 || grep -q "metamodule=1" $MODPATH/module.prop >/dev/null 2>&1 ); then
	echo "[+] mountify will be installed in metamodule mode!"
	mv "$MODPATH/post-fs-data.sh" "$MODPATH/metamount.sh"
fi

# EOF
