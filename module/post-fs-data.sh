#!/system/bin/sh
# This script is executed once after system properly started,
# this is useful to perform custom installation steps after the system and attached modules are loaded.

MODDIR="${0%/*}"
MODDIR="/data/adb/modules/mountify"
PERSISTENT_DIR="/data/adb/mountify"
LOG_FOLDER="/dev/mountify_logs"
DMESG_PREFIX="mountify"

# Read config
. $PERSISTENT_DIR/config.sh

# exit if disabled
if [ $mountify_mounts = 0 ]; then
	string="description=mode: disabled 💀"
	sed -i "s/^description=.*/$string/g" "$MODDIR/module.prop"
	exit 0
fi

# Create log folder
mkdir -p "$LOG_FOLDER"

# Log starting
echo "$DMESG_PREFIX: starting..." >> /dev/kmsg

# Log state before
cat /proc/mounts > "$LOG_FOLDER/before"

# Prepare variables
MNT_FOLDER="${MODDIR}/mnt"
if [ ! -d "$MNT_FOLDER" ]; then
    echo "$DMESG_PREFIX: creating mount folder" >> /dev/kmsg
    mkdir -p "$MNT_FOLDER"
fi

# Check device type
if [ "$use_ext4_sparse" = "1" ] && [ ! -f "$MODDIR/no_tmpfs_xattr" ]; then
    echo "$DMESG_PREFIX: using ext4 sparse mode" >> /dev/kmsg
    
    # Create sparse image
    SPARSE_FILE="${MODDIR}/mountify.sparse"
    SPARSE_SIZE="${sparse_size}M"
    
    if [ ! -f "$SPARSE_FILE" ]; then
        echo "$DMESG_PREFIX: creating sparse image ($SPARSE_SIZE)" >> /dev/kmsg
        dd if=/dev/zero of="$SPARSE_FILE" bs=1M count="${sparse_size}" 2>/dev/null
    fi
    
    # Format as ext4
    mkfs.ext4 -F "$SPARSE_FILE" > /dev/null 2>&1
    
    # Mount sparse image
    mount -t ext4 -o loop "$SPARSE_FILE" "$MNT_FOLDER" 2>/dev/null || {
        echo "$DMESG_PREFIX: failed to mount sparse image" >> /dev/kmsg
        exit 1
    }
else
    # Use tmpfs
    mount -t tmpfs -o size=1024M,mode=0755 mountify_tmpfs "$MNT_FOLDER" 2>/dev/null || {
        echo "$DMESG_PREFIX: failed to mount tmpfs" >> /dev/kmsg
        exit 1
    }
fi

# Check for modules folder
if [ ! -d "$MNT_FOLDER/modules" ]; then
    mkdir -p "$MNT_FOLDER/modules"
fi

# Copy modules
echo "$DMESG_PREFIX: copying modules..." >> /dev/kmsg

if [ "$mountify_mounts" = "1" ]; then
    # Manual mode - read from modules.txt
    if [ -f "/data/adb/modules.txt" ]; then
        while IFS= read -r module_name; do
            if [ -d "/data/adb/modules/$module_name" ] && [ "$module_name" != "mountify" ]; then
                cp -r "/data/adb/modules/$module_name" "$MNT_FOLDER/modules/"
                echo "$module_name" >> "$LOG_FOLDER/modules"
            fi
        done < "/data/adb/modules.txt"
    fi
elif [ "$mountify_mounts" = "2" ]; then
    # Auto mode - mount all modules
    for module_dir in /data/adb/modules/*/; do
        module_name="$(basename "$module_dir")"
        if [ "$module_name" != "mountify" ] && [ -f "$module_dir/module.prop" ]; then
            cp -r "$module_dir" "$MNT_FOLDER/modules/"
            echo "$module_name" >> "$LOG_FOLDER/modules"
        fi
    done
fi

# Create overlay mount points
echo "$DMESG_PREFIX: preparing overlay mounts..." >> /dev/kmsg

for module in "$MNT_FOLDER"/modules/*/; do
    if [ -d "$module" ]; then
        module_name="$(basename "$module")"
        
        # Create overlay structure
        mkdir -p "$MNT_FOLDER/work/$module_name"
        mkdir -p "$MNT_FOLDER/merged/$module_name"
        
        # Mount overlay
        mount -t overlay -o lowerdir="/system",upperdir="$module/system",workdir="$MNT_FOLDER/work/$module_name" overlay "$MNT_FOLDER/merged/$module_name" 2>/dev/null
    fi
done

echo "$DMESG_PREFIX: stage1: unmounting $(realpath "$MNT_FOLDER")" >> /dev/kmsg
busybox umount -l "$MNT_FOLDER"

# handle operating mode
case $mountify_mounts in
	1) mode="manual 🤓" ;;
	2) mode="auto 🤖" ;;
esac

if [ "$use_ext4_sparse" = "1" ] || [ -f "$MODDIR/no_tmpfs_xattr" ]; then
	mode="$mode | fstype: ext4 🛠️"
else
	mode="$mode | fstype: tmpfs 🦾"
fi

# display if on litemode
if [ "$APATCH_BIND_MOUNT" = "true" ] && [ -f /data/adb/.litemode_enable ]; then 
	mode="$mode | litemode: ✅"
fi

# generate description accordingly
string="description=mode: $mode | no modules mounted"
if [ -f $LOG_FOLDER/modules ]; then
	module_list=$( for module in $(cat "$LOG_FOLDER/modules" ) ; do printf "$module " ; done )
	string="description=mode: $mode | modules: $module_list "
fi

# only update when generated string is different
desc_current=$(grep "^description=" "$MODDIR/module.prop")
if [ "$desc_current" != "$string" ]; then
	sed -i "s/^description=.*/$string/g" "$MODDIR/module.prop"
fi

# log after
cat /proc/mounts > "$LOG_FOLDER/after"
echo "$DMESG_PREFIX: finished!" >> /dev/kmsg

# prep logs for status
busybox diff "$LOG_FOLDER/before" "$LOG_FOLDER/after" | grep " $FS_TYPE_ALIAS " > "$MODDIR/mount_diff"

# EOF