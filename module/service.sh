#!/bin/sh
# service.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

# wait for boot-complete
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# placeholder
mode="symlink (wip) 🛠️ "

# display if on nomount/litemode
if [ "$KSU_MAGIC_MOUNT" = "true" ] && [ -f /data/adb/ksu/.nomount ]; then
	mode="$mode | nomount: ✅"
fi
if [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; then 
	mode="$mode | litemode: ✅"
fi

# find logging folder
[ -w /mnt ] && LOG_FOLDER=/mnt/mountify_logs
[ -w /mnt/vendor ] && LOG_FOLDER=/mnt/vendor/mountify_logs

# update description accrdingly
string="description=mode: $mode | no modules mounted"
if [ -f $LOG_FOLDER/modules ]; then
	string="description=mode: $mode | modules: $( for module in $(cat "$LOG_FOLDER/modules" ) ; do printf "$module " ; done ) "
fi
sed -i "s/^description=.*/$string/g" $MODDIR/module.prop

# EOF
