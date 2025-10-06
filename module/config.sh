#!/bin/sh
# config.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.

# mountify config

# module mounting config
# 0 to disable
# 1 for manual mode (this will mount modules found on modules.txt)
# 2 for auto mode (this will mount all modules with a system folder)
mountify_mounts=2

# fake mount time
# since all module files will now be unified to a single folder
# you can use shit like my_bigball, mi_ext, preload_common, special_preload
# you just make this shit up
FAKE_MOUNT_NAME="mountify"

# decoy mount
# you can override here to enable/disable testing of decoy mounting
# this is only meant for tmpfs mode
# 0 to disable
# 1 to enable
test_decoy_mount=0

# stop; start at service
# certain modules might need this
# just set to 1 to enable
mountify_stop_start=0

# for this one, if unsure, do NOT touch.
# fake overlayfs params
# this is only useful if you patched your overlayfs to register some made up alias
FS_TYPE_ALIAS="overlay"

# this one below is its device name
# you can put "KSU", "APatch" here so a umount provider can umount
# e.g. NeoZygisk, NoHello, ReZygisk, Shamiko, Zygisk Assistant, ZygiskNext-DE
# otherwise leave default. this is if you need unmount.
MOUNT_DEVICE_NAME="overlay"

#
# settings below are mostly for sparse mode users !!!
#

# ext4 sparse mode override
# this only makes sense if you have tmpfs xattr but you still
# prefer using an ext4 sparse image to mount
# NOTE: this causes detections, but no real app does as of 250911
# 0 to disable
# 1 to enable
use_ext4_sparse=0

# this tries to spoof your sparse mount as some apex service whatever
# this makes sense if you unmount your overlays, so this should go well
# with a custom MOUNT_DEVICE_NAME
# 0 to disable
# 1 to enable
spoof_sparse=0

# this is your fake apex name
# just put random bullshit on this like com.android.wtf
# while futile, this tries to make it look legit
FAKE_APEX_NAME="com.android.mntservice"

# this is for users who wants a custom sparse size
# this does NOT really matter, but it seems important to some
# modify this to any unsigned number
# basically, sparse size in MB
sparse_size="2048"

# EOF
