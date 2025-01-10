#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

echo "[+] mount-ify"
echo "[+] extended status"
printf "\n\n"

[ -w /mnt ] && MNT_FOLDER=/mnt
[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor

if [ -d $MODDIR/whiteouts ]; then
	busybox tree $MODDIR/whiteouts
fi

for i in $(awk {'print $2'} $MODDIR/modules.txt); do
	[ -d "$MNT_FOLDER/$i" ] && busybox tree $MNT_FOLDER/$i
done

# ksu and apatch auto closes
# make it wait 20s so we can read
if [ -z "$MMRL" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
	sleep 20
fi

# EOF
