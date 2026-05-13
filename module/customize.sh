#MAGISK

PROPS="ro.debuggable
ro.secure
ro.boot.serialno
ro.bootloader
ro.bootmode
ro.com.google.clientidbase
ro.board.platform
ro.hardware
ro.product.board"

DIR="$(cd "$(dirname "$0")" && pwd)"
MODDIR="${0%/*}"

set_perm_recursive "$MODDIR" 0 0 0755 0644
set_perm "$MODDIR/post-fs-data.sh" 0 0 0755
set_perm "$MODDIR/service.sh" 0 0 0755
set_perm "$MODDIR/uninstall.sh" 0 0 0755

# Create necessary directories
mkdir -p "$MODDIR/system/etc"
mkdir -p "$MODDIR/system/lib"

# exit if disabled
if [ ! -d "/data/adb/mountify" ]; then
    mkdir -p "/data/adb/mountify"
    echo "mountify_mounts=2" > "/data/adb/mountify/config.sh"
    echo "mountify_stop_start=0" >> "/data/adb/mountify/config.sh"
    echo "FAKE_MOUNT_NAME=Mountify" >> "/data/adb/mountify/config.sh"
    echo "FS_TYPE_ALIAS=overlay" >> "/data/adb/mountify/config.sh"
    echo "MOUNT_DEVICE_NAME=magisk" >> "/data/adb/mountify/config.sh"
    echo "use_ext4_sparse=0" >> "/data/adb/mountify/config.sh"
    echo "spoof_sparse=0" >> "/data/adb/mountify/config.sh"
    echo "FAKE_APEX_NAME=com.android.apex" >> "/data/adb/mountify/config.sh"
    echo "sparse_size=500" >> "/data/adb/mountify/config.sh"
    echo "mountify_custom_umount=0" >> "/data/adb/mountify/config.sh"
    echo "test_decoy_mount=0" >> "/data/adb/mountify/config.sh"
    echo "mountify_expert_mode=0" >> "/data/adb/mountify/config.sh"
    echo "enable_lkm_nuke=0" >> "/data/adb/mountify/config.sh"
    echo "lkm_filename=gki" >> "/data/adb/mountify/config.sh"
fi

# Read config
. /data/adb/mountify/config.sh

PERSISTENT_DIR="/data/adb/mountify"

echo "Checking for conflicts..."

if [ "$MAGISK" = true ]; then
	echo "[✓] Magisk detected"
elif [ "$KSU" = true ]; then
	echo "[✓] KernelSU detected"
	
	# Check susfs version
	SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"
	if [ "$KSU" = true ] && [ -f ${SUSFS_BIN} ]; then
		SUSFS_VERSION="$( ${SUSFS_BIN} show version | head -n1 | sed 's/v//; s/\.//g' 2> /dev/null )"
		if { [ "$SUSFS_VERSION" -eq 1510 ] || [ "$SUSFS_VERSION" -eq 1511 ] || [ "$SUSFS_VERSION" -eq 210 ]; }; then
			printf "\n\n"
			echo "[!] ERROR: Mountify causes conflicts with this susfs version."
			echo "[!] This setup can cause issues and is NOT recommended."
			echo "[!] Please update KernelSU or downgrade susfs."
			printf "\n\n"
			abort
		fi
	fi
elif [ "$APATCH" = true ]; then
	echo "[✓] APatch detected"
else
	echo "[!] No compatible root detected"
	abort
fi

echo "[✓] All checks passed"