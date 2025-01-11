#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs
MODDIR="/data/adb/modules/mountify"

# functions
# whiteout_create
whiteout_create() {
	mkdir -p "$MODDIR/whiteouts/${1%/*}"
  	busybox mknod "$MODDIR/whiteouts/$1" c 0 0
  	busybox setfattr -n trusted.overlay.whiteout -v y "$MODPATH/whiteouts/$1"
  	chmod 644 "$MODDIR/whiteouts/$1"
}

# --
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
# this will regenrate whiteouts when change is detected
newhash=$(cat "$MODDIR/whiteouts.txt" | busybox crc32)
oldhash=$(cat "$MODDIR/whiteouts.txt.crc" )

if [ ! "$newhash" = "$oldhash" ]; then
	rm -rf "$MODDIR/whiteouts"
	for line in $( sed '/#/d' "$MODDIR/whiteouts.txt" ); do
		whiteout_create "$line"
	done
	# regen crc
	cat "$MODDIR/whiteouts.txt" | busybox crc32 > "$MODDIR/whiteouts.txt.crc"
fi

if [ -d $MODDIR/whiteouts ]; then
	mnt_fname="my_whiteouts"
	[ -w /mnt ] && MNT_FOLDER=/mnt
	[ -w /mnt/vendor ] && MNT_FOLDER=/mnt/vendor
	mkdir $MNT_FOLDER/$mnt_fname
	${SUSFS_BIN} add_sus_path $MNT_FOLDER/$mnt_fname
	cd $MODDIR/whiteouts

	for i in $(ls -d */*); do
		mkdir -p "$MNT_FOLDER/$mnt_fname/$i"
		mount --bind "$MODDIR/whiteouts/$i" "$MNT_FOLDER/$mnt_fname/$i"
		mount -t overlay -o "lowerdir=$MNT_FOLDER/$mnt_fname/$i:/$i" overlay "/$i"
		${SUSFS_BIN} add_sus_mount "/$i"
	done
fi

# EOF
