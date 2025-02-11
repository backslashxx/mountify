#!/bin/sh
# config.sh
# this script is part of mountify
# No warranty.
# No rights reserved.
# This is free software; you can redistribute it and/or modify it under the terms of The Unlicense.

# mountify config
# module mounting
# just set to 0 to disable
mountify_mounts=1

# toggle to use susfs
# this is not really required as of 250211
# it seems recent susfs will just omit mounts done within ksu domain (100000+ mount id)
# and no detector detects mountify mounting method yet, so no need to enforce/require
# just set to 1 to enable
mountify_use_susfs=0

# stop; start at service
# certain modules might need this
# just set to 1 to enable
mountify_stop_start=0

# EOF
