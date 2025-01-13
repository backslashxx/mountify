#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

echo "[+] mount-ify"
echo "[+] extended status"
printf "\n\n"

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
