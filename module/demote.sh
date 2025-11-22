#!/bin/sh
# demote.sh
# mountify's demoter script
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
PERSISTENT_DIR="/data/adb/mountify"

if [ ! -f "$MODDIR/metamount.sh" ]; then
	echo "[!] already demoted"
	exit 1
fi

echo "[+] demoting mountify"
mv "$MODDIR/metamount.sh" "$MODDIR/post-fs-data.sh"
sed -i '|^metamodule|d' $MODDIR/module.prop

if [ -L "/data/adb/metamodule" ]; then
	rm -f "/data/adb/metamodule"
fi

echo "[+] you can now install another metamodule!"
echo "[!] WARNING: I hope you know what you're doing!"

touch "$PERSISTENT_DIR/mountify_demoted"

# EOF
