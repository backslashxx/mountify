#!/bin/sh
# uninstall.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

# remove skip_mount on modules we skip_mounted
for module in $(cat /data/adb/modules/mountify/skipped_modules) ; do 
	rm /data/adb/modules/"$module"/skip_mount > /dev/null 2>&1
done

# EOF
