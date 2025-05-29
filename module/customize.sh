#!/bin/sh
# customize.sh
# system requirement test for mountify (symlink ver)
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

# routine start
echo "[+] mountify (symlink ver)"
echo "[+] SysReq test"

## test for casefolding

# standard sanity checks
if [ ! -d /data/adb/modules ]; then
	abort "[?] no /data/adb/modules"
fi

# create this folder
TEST_FOLDER="/data/adb/modules/mountify_casefold_test"

[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"
mkdir -p "$TEST_FOLDER" || abort "[x] cant create test folder"

# create files
echo "CASEFOLD_TEST_UPPERCASE" >> "$TEST_FOLDER/CASEFOLD"
echo "casefold_test_lowercase" >> "$TEST_FOLDER/casefold"

if [ -f "$TEST_FOLDER/CASEFOLD" ] && [ -f "$TEST_FOLDER/casefold" ]; then
	# casefold test
	if busybox diff -q "$TEST_FOLDER/CASEFOLD" "$TEST_FOLDER/casefold" >/dev/null 2>&1; then
		# both files exist, but resolves to same inode, casefolded
		abort "[x] files created, but resolves to same inode, casefolded"
	else
		# different contents — true case-sensitive FS
		echo "[+] /data/adb/modules is NOT casefolded"
	fi
else
	# files cant coexist, case-insensitive
	abort "[x] files not created, casefolded"

fi

[ -d "$TEST_FOLDER" ] && rm -rf "$TEST_FOLDER"


# EOF
