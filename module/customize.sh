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

# feel free to comment this condition out to bypass
# but this is not a recommended configuration
if { [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ]; } || { [ "$APATCH" = true ] && [ ! "$APATCH_BIND_MOUNT" = true ]; }; then
	abort "[!] Unsupported configuration!"
fi

# theres reports that it bootloops on certain devices
# split it from top condition for readability
if getprop ro.product.name | grep -q 'vermeer' ; then
	abort "[!] Unsupported configuration!"
fi

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
testfile="/debug_ramdisk/tmpfs_xattr_testfile"
rm $testfile > /dev/null 2>&1 
busybox mknod "$testfile" c 0 0 > /dev/null 2>&1 
if busybox setfattr -n trusted.overlay.whiteout -v y "$testfile" > /dev/null 2>&1 ; then 
	echo "[+] CONFIG_TMPFS_XATTR"
	echo "[+] tmpfs extended attribute test passed"
else
	abort "[!] CONFIG_TMPFS_XATTR is required for this module!"
fi

configs="modules.txt whiteouts.txt config.sh"
for file in $configs; do
	if [ -f "/data/adb/modules/mountify/$file" ]; then
		echo "[+] migrating $file"
		cat "/data/adb/modules/mountify/$file" > "$MODPATH/$file"
	fi
done

# EOF
