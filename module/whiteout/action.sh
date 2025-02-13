#!/bin/sh
# action.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="${0%/*}"

echo "[+] mountify"
echo "[+] whiteouts"
printf "\n\n"

if [ -d $MODDIR/system ]; then
	busybox tree $MODDIR/system
fi

# ksu and apatch auto closes
# make it wait 20s so we can read
if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ]  && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
	sleep 20
fi

# EOF
