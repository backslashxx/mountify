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
# 
# 1 and 2 will always stay manual on symlink version
mountify_mounts=2

# fake mount time
# since all module files will now be unified to a single folder
# you can use shit like my_bigball, mi_ext, preload_common, special_preload
# you just make this shit up
#
# this is ignored on symlink version
FAKE_MOUNT_NAME="mountify"

# toggle to use susfs
# this is not really required as of 250211
# it seems recent susfs will just omit mounts done within ksu domain (100000+ mount id)
# and no detector detects mountify mounting method yet, so no need to enforce/require
# just set to 1 to enable
mountify_use_susfs=0

# stop; start at service
# certain modules might need this
# just set to 1 to enable
mountify_stop_start=0

# for settings below, if unsure, do NOT touch.

# fake overlayfs params
# this is only useful if you patched your overlayfs to register some made up alias
FS_TYPE_ALIAS="overlay"

# this one below is its device name
# you can put whatever bullshit you want here like '/dev/block/dm-0' whatever
# if umount is needed, you can use "KSU" as devicename and then NoHello / ksu_mount_monitor will unmount it.
MOUNT_DEVICE_NAME="overlay"

# EOF
