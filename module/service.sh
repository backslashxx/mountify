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

[ ! -f $MODDIR/modules.txt ] && touch $MODDIR/modules.txt

# grab module list
modlist="modules:"
for module in $(awk {'print $1'} $MODDIR/modules.txt); do
	if [ -d "/data/adb/modules/$module/system" ] && [ ! -f "/data/adb/modules/$module/disable" ] && 
		[ ! -f "/data/adb/modules/$module/remove" ] && [ ! $module = "bindhosts" ]; then
		modlist="$modlist $module"
	fi
done

# create module list for status
if [ "$(echo $modlist | wc -w)" -gt 1 ]; then
	string="description=$modlist"
else
	string="description=no modules mounted"
fi

sed -i "s/^description=.*/$string/g" $MODDIR/module.prop

# EOF
