#!/bin/sh
# whiteout_gen.sh
# mountify's whiteout module creator
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
MODDIR="/data/adb/modules/mountify"
MODULE_UPDATES_DIR="/data/adb/modules_update/mountify_whiteouts"
MODULE_DIR="/data/adb/modules/mountify_whiteouts"

if [ -z $1 ] || [ ! -f $1 ]; then
	echo "[!] missing arguments or inaccessible textfile"
	exit 1
fi
TEXTFILE="$(realpath $1)"

# mark module for update
mkdir -p $MODULE_DIR ; touch $MODULE_DIR/update
# create 
mkdir -p $MODULE_UPDATES_DIR ; cd $MODULE_UPDATES_DIR
busybox chcon --reference="/system" "$MODULE_UPDATES_DIR"

whiteout_create() {
	echo "$MODULE_UPDATES_DIR${1%/*}"
	echo "$MODULE_UPDATES_DIR$1" 
	mkdir -p "$MODULE_UPDATES_DIR${1%/*}"
  	busybox mknod "$MODULE_UPDATES_DIR$1" c 0 0
  	busybox chcon --reference="/system" "$MODULE_UPDATES_DIR$1"  
  	# not really required, mountify() does NOT even copy the attribute but ok
  	busybox setfattr -n trusted.overlay.whiteout -v y "$MODULE_UPDATES_DIR$1"
  	chmod 644 "$MODULE_UPDATES_DIR$1"
}

for line in $( sed '/#/d' "$TEXTFILE" ); do
	echo "$line" | grep -q "^/system/" && whiteout_create "$line" > /dev/null 2>&1
	ls "$MODULE_UPDATES_DIR$line" 2>/dev/null
done

# import resources for whiteout module
cat "$MODDIR/whiteout/module.prop" > "$MODULE_UPDATES_DIR/module.prop"
cat "$MODDIR/whiteout/action.sh" > "$MODULE_UPDATES_DIR/action.sh"

# EOF
