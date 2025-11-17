#!/bin/sh
# uninstall.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
FLAGS="/data/adb/ksu/.nomount
/data/adb/ksu/.notmpfs
/data/adb/.litemode_enable"

# remove skip_mount on modules we skip_mounted
for module in $(cat /data/adb/mountify/skipped_modules) ; do 
	rm /data/adb/modules/"$module"/skip_mount > /dev/null 2>&1
done

# remove flags created by mountify webui
for flag in $FLAGS; do
	if [ -f "$flag" ] && grep -q "mountify" "$flag"; then
		rm -f "$flag"
	fi
done

# delete config directory
[ -d "/data/adb/mountify/" ] && rm -rf "/data/adb/mountify/"

# EOF
