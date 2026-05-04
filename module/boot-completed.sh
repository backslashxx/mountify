#!/bin/sh
# boot-completed.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
# read config
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh

LOG_FOLDER="/dev/mountify_logs"

# reset bootcount (anti-bootloop routine)
echo "BOOTCOUNT=0" > "$MODDIR/count.sh"

# remove mountify single instance lock
MOUNTIFY_LOCK="/dev/mountify_single_instance"
if [ -f "$MOUNTIFY_LOCK" ]; then
	echo "mountify/boot-completed: lifting single instance lock" >> /dev/kmsg
	rm "$MOUNTIFY_LOCK"
fi

# clean log folder
[ -d "$LOG_FOLDER" ] && rm -rf "$LOG_FOLDER"

# EOF
