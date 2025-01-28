#!/bin/sh
# action.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

echo "[+] mount-ify"
echo "[+] extended status"
printf "\n\n"

# basic bs for now
# make it better maybe tomorrow

if [ -d /debug_ramdisk/mountify/wo ]; then
	busybox tree /debug_ramdisk/mountify/wo
fi

grep overlay /proc/mounts

# ksu and apatch auto closes
# make it wait 20s so we can read
if [ -z "$MMRL" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
	sleep 20
fi

# EOF
