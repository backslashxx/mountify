#!/bin/sh
# post-fs-data.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"

# grab start time
echo "mountify/post-fs-data: start!" >> /dev/kmsg

# module mount section
# modules.txt
# <modid> <fake_folder_name>
IFS="
"
for line in $( sed '/#/d' "$MODDIR/modules.txt" ); do
	module_id=$( echo $line | awk {'print $1'} )
	folder_name=$( echo $line | awk {'print $2'} )
	sh "$MODDIR/mount.sh" "$module_id" "$folder_name"
done

echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
