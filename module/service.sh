#!/bin/sh
# service.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"
mountify_stop_start=0
# read config
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh

# stop; start
# restart android at service
# this is a bit of a workaround for "racey" modules.
# I do NOT know how to explain it, but it is like on some modules
# mounting is LATE. this happens especially with certain gpu drivers
# and even as simple as bootanimation modules.
# if you do NOT have the issue, you do NOT need this.
# this is disabled by default on config.sh
if [ $mountify_stop_start = 1 ]; then
	stop; start
fi

# handle operating mode
case $mountify_mounts in
	1) mode="manual 🤓" ;;
	2) mode="auto 🤖" ;;
	*) mode="disabled 💀" ;; # ??
esac

if [ "$use_ext4_sparse" = "1" ] || [ -f "$MODDIR/no_tmpfs_xattr" ]; then
	mode="$mode | fstype: ext4 🛠️"
else
	mode="$mode | fstype: tmpfs 🦾"
fi

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

# wait for boot-complete
until [ "$(getprop sys.boot_completed)" = "1" ]; do
	sleep 1
done

# reset bootcount (anti-bootloop routine)
echo "BOOTCOUNT=0" > "$MODDIR/count.sh"

if [ ! "$APATCH" = true ] && [ ! "$KSU" = true ]; then
	sh "$MODDIR/boot-completed.sh" &
fi

# EOF
