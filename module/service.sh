#!/system/bin/sh
# This script is executed once after system properly started,
# this is useful to perform custom installation steps after the system and attached modules are loaded.

MODDIR="${0%/*}"
MODDIR="/data/adb/modules/mountify"
PERSISTENT_DIR="/data/adb/mountify"
LOG_FOLDER="/dev/mountify_logs"
DMESG_PREFIX="mountify"

. $PERSISTENT_DIR/config.sh

# disable if needed
if [ "$mountify_mounts" = 0 ]; then
    echo "$DMESG_PREFIX: mountify is disabled" >> /dev/kmsg
    exit 0
fi

# Check for KSU
if [ "$mountify_custom_umount" = 2 ]; then
    KSUD_PATH="/data/adb/ksud"
    if [ ! -f "$KSUD_PATH" ]; then
        echo "$DMESG_PREFIX: ksud not found, disabling ksud unmount" >> /dev/kmsg
        sed -i 's/mountify_custom_umount=2/mountify_custom_umount=0/g' "$PERSISTENT_DIR/config.sh"
        exit 0
    fi
fi

do_ksud_umount() {
for mount in $(cat "$LOG_FOLDER/mountify_mount_list"); do
 	/data/adb/ksud kernel umount add "$mount" --flags 2 > /dev/null 2>&1
done

# now inform ksud so that the kernel unlocks the feature
/data/adb/ksud kernel notify-module-mounted >/dev/null 2>&1
}

if [ "$mountify_custom_umount" = 1 ]; then
    echo "$DMESG_PREFIX: using susfs4ksu" >> /dev/kmsg
    # susfs4ksu
elif [ "$mountify_custom_umount" = 2 ]; then
    echo "$DMESG_PREFIX: using ksud kernel unmount" >> /dev/kmsg
    do_ksud_umount &
fi

# wait for boot-complete
if [ ! "$APATCH" = true ] && [ ! "$KSU" = true ]; then
 	until [ "$(getprop sys.boot_completed)" = "1" ]; do
		sleep 1
	done
 	sh "$MODDIR/boot-completed.sh" &
fi

# prep logs for status
busybox diff "$LOG_FOLDER/before" "$LOG_FOLDER/after" | grep " $FS_TYPE_ALIAS " > "$MODDIR/mount_diff"

# EOF