#!/bin/sh
# test-sysreq.sh
# system requirement test for mountify standalone
# you can put or execute this on customize.sh of a module.
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

# routine start
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
[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor
testfile="$MNT_FOLDER/tmpfs_xattr_testfile"
rm $testfile > /dev/null 2>&1 
busybox mknod "$testfile" c 0 0 > /dev/null 2>&1 
if busybox setfattr -n trusted.overlay.whiteout -v y "$testfile" > /dev/null 2>&1 ; then 
	echo "[+] CONFIG_TMPFS_XATTR"
	echo "[+] tmpfs extended attribute test passed"
	rm $testfile > /dev/null 2>&1 
else
	rm $testfile > /dev/null 2>&1 
	abort "[!] CONFIG_TMPFS_XATTR is required for this module!"
fi

# warn on OverlayFS managers
# while this is supported (half-assed), this is not a recommended configuration
if { [ "$KSU" = true ] && [ ! "$KSU_MAGIC_MOUNT" = true ]; } || { [ "$APATCH" = true ] && [ ! "$APATCH_BIND_MOUNT" = true ]; }; then
	printf "\n\n"
	echo "[!] WARNING: Root manager is NOT on magic mount."
	echo "[!] This setup can cause issues and is NOT recommended."
fi

# mountify 131 added this
# this way mountify wont remount this module
[ ! -f $MODPATH/skip_mountify ] && touch $MODPATH/skip_mountify

# EOF
