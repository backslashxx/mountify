#!/bin/sh
# metainstall.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.

# so other modules can identify
# mind you mountify restores magic mount folder hierarchy!
export KSU_HAS_METAMODULE="true"
export KSU_METAMODULE="mountify"
export MOUNTIFY="true"

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

# call install function, this is important!
install_module

# EOF

