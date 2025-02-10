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
. $MODDIR/config.sh

# stop; start
if [ $mountify_stop_start = 1 ]; then
	stop; start
fi

# wait for boot
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# find logging folder
[ -w /tmp ] && LOG_FOLDER=/tmp/mountify
[ -w /sbin ] && LOG_FOLDER=/sbin/mountify
[ -w /debug_ramdisk ] && LOG_FOLDER=/debug_ramdisk/mountify

# update description accrdingly
string="description=no modules mounted"
if [ -f $LOG_FOLDER/modules ]; then
	string="description=modules: $( for module in $(cat "$LOG_FOLDER/modules" ) ; do printf "$module " ; done ) "
fi
sed -i "s/^description=.*/$string/g" $MODDIR/module.prop

# EOF
