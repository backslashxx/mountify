#!/bin/sh
# test-sysreq.sh
# system requirement test for mountify standalone
# you can put or execute this on customize.sh of a module.
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.

# routine start
echo "[+] mountify"
echo "[+] SysReq test"

# test if we are on OverlayFS KernelSU
if [ "$KSU" = "true" ] && [ -z "$KSU_MAGIC_MOUNT" ]; then
	echo "OK!"
else
	abort "[!] This is meant only for KernelSU OverlayFS!"
fi

# EOF
