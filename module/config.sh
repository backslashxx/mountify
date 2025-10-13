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

# fake mount name
# mount folder name
FAKE_MOUNT_NAME="mountify"

# Test for decoy mounting.
# This is meant for tmpfs mode.
# 0 to disable
# 1 to enable
test_decoy_mount=0

# restart android at at service
# certain modules might need this
# 0 to disable
# 1 to enable
mountify_stop_start=0

# You can put 'KSU', 'APatch', 'magisk' here so a umount provider can umount.
# Examples: NeoZygisk, NoHello, ReZygisk, Shamiko, Zygisk Assistant, ZygiskNext-DE
FS_TYPE_ALIAS="overlay"

# this one below is its device name
# you can put "KSU", "APatch" here so a umount provider can umount
# e.g. NeoZygisk, NoHello, ReZygisk, Shamiko, Zygisk Assistant, ZygiskNext-DE
# otherwise leave default. this is if you need unmount.
MOUNT_DEVICE_NAME="overlay"

# WARNING!
# This disables mountify's safety checks. mostly for debugging purposes.
# 0 - disable
# 1 - enable
# YOU HAVE BEEN WARNED
mountify_expert_mode=0

#
# settings below are mostly for sparse mode users !!!
#

# ext4 sparse mode override.
# For tmpfs xattr capable setups that prefers using an ext4 sparse image to mount.
# 0 - disable
# 1 - enable
use_ext4_sparse=0

# Spoof sparse as an apex mount.
# Goes well with a custom MOUNT_DEVICE_NAME.
# NOTE: when this is enabled, LKM nuking is disabled.
# 0 to disable
# 1 to enable
spoof_sparse=0

# Customize spoofed apex mount name.
# While futile, this tries to make it look legit.
FAKE_APEX_NAME="com.android.mntservice"

# Set a custom sparse size.
# Modify this to any unsigned number.
# - sparse size in MB
sparse_size="2048"

# WARNING! 
# Experimental feature. Don't expect 100% success rate.
# Loads a oneshot LKM that unregisters ext4 sysfs nodes. 
# 0 - disable
# 1 - enable
enable_lkm_nuke=0
lkm_filename="nuke.ko"

# EOF
