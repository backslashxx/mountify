#!/bin/sh
MODDIR="${0%/*}"

# modules.txt
# <modid> <fake_folder_name>

while read -r line; do 
	set $line
	sh $MODDIR/mount.sh $1 $2
done < $MODDIR/modules.txt

# EOF
