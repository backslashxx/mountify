#!/bin/sh
# action.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
. $MODDIR/config.sh

echo "[+] mountify"
echo "[+] extended status"
printf "\n\n"

# hunt logging floder
[ -w /mnt ] && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && LOG_FOLDER=/mnt/vendor/mountify_logs

# check if fake alias exists, if fail use overlay
if ! grep "nodev" /proc/filesystems | grep -q "$FS_TYPE_ALIAS" > /dev/null 2>&1; then
	FS_TYPE_ALIAS="overlay"
fi

if [ -f "$MODDIR/mount_diff" ]; then
	cat "$MODDIR/mount_diff"
else
	echo "[!] no logs found!"
fi

# ksu and apatch auto closes
# make it wait 20s so we can read
if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ]  && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
	sleep 20
fi

# EOF
