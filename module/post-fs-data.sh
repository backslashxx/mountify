#!/bin/sh
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

# whiteouts section
# whiteouts.txt
# <file_to_whiteout>
sh "$MODDIR/whiteout.sh" 

echo "mountify/post-fs-data: finished!" >> /dev/kmsg

# EOF
