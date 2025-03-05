#!/bin/sh
# whiteout_gen.sh
# mountify's whiteout module creator
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
MODULE_UPDATES_DIR="/data/adb/modules_update/mountify_whiteouts"
MODULE_DIR="/data/adb/modules/mountify_whiteouts"

echo "[+] mountify's whiteout generator"

if [ -z $1 ] || [ ! -f $1 ]; then
	echo "[!] list missing or not specified!"
	echo "[!] using whiteouts.txt"
	TEXTFILE="$MODDIR/whiteouts.txt"
	if [ ! -f $TEXTFILE ]; then
		echo "[!] whiteouts.txt not found!"
		exit 1
	fi
else
	TEXTFILE="$(realpath $1)"
fi

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
	if echo "$line" | grep -Eq "^/(product|vendor|odm|system_ext)/"; then
		line="/system$line"
	elif ! echo "$line" | grep -q "^/system/"; then
		echo "[!] Invalid input $line. Skipping..."
		continue
    fi
	whiteout_create "$line" > /dev/null 2>&1
	ls "$MODULE_UPDATES_DIR$line" 2>/dev/null
done

# special dirs
# handle this properly so this script can be used standalone
# so yeah, symlinks.
IFS="
"
targets="odm
product
system_ext
vendor"

# this assumes magic mount
for dir in $targets; do 
	if [ -d /$dir ] && [ ! -L /$dir ] && [ -d "$MODULE_UPDATES_DIR/system/$dir" ]; then
		echo "[+] creating symlink for /$dir"
		ln -sf "./system/$dir" "$MODULE_UPDATES_DIR/$dir"
	fi
done

# import resources for whiteout module
cat "$MODDIR/whiteout/module.prop" > "$MODULE_UPDATES_DIR/module.prop"
cat "$MODDIR/whiteout/action.sh" > "$MODULE_UPDATES_DIR/action.sh"

# EOF
