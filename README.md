# mountify
- symlink ver
- requires **CONFIG_OVERLAY_FS=y**
- ‼️ requires **non-casefolded /data/adb/modules**
- tries to mimic an OEM mount, like /mnt/vendor/my_bigball

## Methodology
1. symlink module_dir to /mnt/vendor/my_bigball
2. mount /mnt/vendor/my_bigball as overlayfs lowerdir, e.g. `lowerdir=/mnt/vendor/my_bigball/app:/system/app`
3. do that for all modules on list

## Why?
- I did this to save on RAM usage on Ultra-Legacy devices.
- original version copies files to a tmpfs, this avoids that.

## Usage
only manual mode is offerred, auto does not make sense on this currently.

- modify modules.txt to list modules you want mounted
- first argument is module_name, second argument is fake mount name
```
Adreno_Gpu_Driver my_video
DisplayFeatures my_display
system_app_nuker my_whiteout
weebu-addon my_audio
```

## Limitations / Recommendations
- same as original version

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.
