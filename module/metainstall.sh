#!/bin/sh
# metainstall.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.

# so other modules can identify
# mind you mountify restores magic mount folder hierarchy!
if [ "$KSU" = true ]; then
	export KSU_HAS_METAMODULE="true"
	export KSU_METAMODULE="mountify"
fi

if [ "$APATCH" = true ]; then
	export APATCH_HAS_METAMODULE="true"
	export APATCH_METAMODULE="mountify"
fi

export MOUNTIFY="true"
export MOUNTIFY_HAS_HOT_INSTALL="true"

# restore REPLACE
mark_replace() {
	# REPLACE must be directory!!!
	# https://docs.kernel.org/filesystems/overlayfs.html#whiteouts-and-opaque-directories
	mkdir -p $1 2>/dev/null
	setfattr -n trusted.overlay.opaque -v y $1
	chmod 644 $1
}

# we no-op handle_partition
# because ksu moves them e.g. MODDIR/system/product to MODDIR/product
# this way we can support normal hierarchy that ksu changes
handle_partition() {
	echo 0 > /dev/null ; true
}

# give symlink
# mountify does NOT need this but, some modules still assume
# access to these folders on $MODDIR root
mountify_handle_partition() {
	partition="$1"

	if [ ! -d "$MODPATH/system/$partition" ]; then
		return
	fi

	if [ -L "/system/$partition" ] && [ -d "/$partition" ]; then
		ui_print "- Handle partition /$partition"
		ln -sf "./system/$partition" "$MODPATH/$partition"
	fi
}

# call install function, this is important!
install_module

mountify_handle_partition system_ext
mountify_handle_partition vendor
mountify_handle_partition product
mountify_handle_partition odm

mountify_hot_install() {

	# ksu only for now, verify on apatch later
	if [ ! "$KSU" = true ]; then
		return
	fi

	if [ -z "$MODID" ]; then
		return
	fi

	MODDIR_INTERNAL="/data/adb/modules/$MODID"
	MODPATH_INTERNAL="/data/adb/modules_update/$MODID"

	if [ ! -d "$MODDIR_INTERNAL" ] || [ ! -d "$MODPATH_INTERNAL" ]; then
		return
	fi

	# hot install
	busybox rm -rf "$MODDIR_INTERNAL"
	busybox mv "$MODPATH_INTERNAL" "$MODDIR_INTERNAL"

	# run script requested, blocking, just fork it yourselves if you want it on background
	if [ ! -z "$MODULE_HOT_RUN_SCRIPT" ]; then
		[ -f "$MODDIR_INTERNAL/$MODULE_HOT_RUN_SCRIPT" ] && sh "$MODDIR_INTERNAL/$MODULE_HOT_RUN_SCRIPT"
	fi

	# we do this dance to satisfy kernelsu's ensure_file_exists
	mkdir -p "$MODPATH_INTERNAL"
	cat "$MODDIR_INTERNAL/module.prop" > "$MODPATH_INTERNAL/module.prop"

	( sleep 3 ; 
		rm -rf "$MODDIR_INTERNAL/update" ; 
		rm -rf "$MODPATH_INTERNAL"
	) & # fork in background

	echo "- Module hot install requested!"
	echo "- Refresh module page after installation!"
	echo "- No need to reboot!"
}

if [ "$MODULE_HOT_INSTALL_REQUEST" = true ]; then
	mountify_hot_install
fi

# EOF
