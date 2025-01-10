#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
MODDIR="/data/adb/modules/mountify"

# wait for boot
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# count whiteouts
wo_cnt=0
if [ -d $MODDIR/whiteouts ]; then
	wo_cnt=$( busybox tree $MODDIR/whiteouts | tail -n 1 | awk {'print $3'} )
fi
string="description=whiteouts: $wo_cnt"

[ ! -f $MODDIR/modules.txt ] && touch $MODDIR/modules.txt
# grab module list
modlist="modules:"
for i in $(awk {'print $1'} $MODDIR/modules.txt); do
	[ -d /data/adb/modules/$i ] && modlist="$modlist $i"
done

# create module list for status
if [ "$(echo $modlist | wc -w)" -gt 1 ]; then
	string="description=whiteouts: $wo_cnt | $modlist"
fi

sed -i "s/^description=.*/$string/g" $MODDIR/module.prop

# EOF
