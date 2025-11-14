#!/bin/sh

# restore REPLACE
mark_replace() {
	# REPLACE must be directory!!!
	# https://docs.kernel.org/filesystems/overlayfs.html#whiteouts-and-opaque-directories
	mkdir -p $1 2>/dev/null
	setfattr -n trusted.overlay.opaque -v y $1
	chmod 644 $1
}

# undo_handle_partition
# because ksu moves them e.g. MODDIR/system/product to MODDIR/product
# this way we can support normal hierarchy that ksu breaks
undo_handle_partition() {
	partition_to_undo="$1"
	if [ -L "$MODPATH/system/$partition_to_undo" ] && [ -d "$MODPATH/$partition_to_undo" ]; then
		# ui_print "- undo handle_partition for /$partition_to_undo"
		rm -f "$MODPATH/system/$partition_to_undo"
		mv -f "$MODPATH/$partition_to_undo" "$MODPATH/system/$partition_to_undo"
	fi
}

install_module

# Handle replace folders
for TARGET in $REPLACE; do
    ui_print "- Replace target: $TARGET"
    mark_replace $MODPATH$TARGET
done


# Run for typical partitions
undo_handle_partition vendor
undo_handle_partition product
undo_handle_partition system_ext
undo_handle_partition odm

# ui_print "- mountify: undo handle_partition"

# EOF

