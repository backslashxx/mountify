#!/system/bin/sh
# This script is executed once after successful installation of the module.
# You can use this script to perform custom installation steps.

MODDIR="${0%/*}"
MODDIR="/data/adb/modules/mountify"
PERSISTENT_DIR="/data/adb/mountify"
. $PERSISTENT_DIR/config.sh

LOG_FOLDER="/dev/mountify_logs"

# reset bootcount (anti-bootloop routine)
echo "BOOTCOUNT=0" > "$MODDIR/count.sh"

# remove mountify single instance lock
MOUNTIFY_LOCK="/dev/mountify_single_instance"
if [ -f "$MOUNTIFY_LOCK" ]; then
	echo "mountify/boot-completed: lifting single instance lock" >> /dev/kmsg
	rm "$MOUNTIFY_LOCK"
fi

# clean log folder
[ -d "$LOG_FOLDER" ] && rm -rf "$LOG_FOLDER"

# EOF