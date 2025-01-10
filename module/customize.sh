#!/bin/sh
# customize.sh

if ! grep -q overlay /proc/filesystems > /dev/null 2>&1; then \
	abort "[!] OverlayFS is required for this module!"
fi

configs="modules.txt whiteouts.txt"
for file in $configs; do
	if [ -f "/data/adb/modules/mountify/$file" ]; then
		echo "[+] migrating $file"
		cat "/data/adb/modules/mountify/$file" > "$MODPATH/$file"
	fi
done

# EOF
