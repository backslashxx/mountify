#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

if ! grep -q overlay /proc/filesystems > /dev/null 2>&1; then \
	abort "[!] OverlayFS is required for this module!"
fi

