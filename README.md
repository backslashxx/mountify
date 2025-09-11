# Mountify

#### Globally mounted modules via OverlayFS.

- mostly meant for [MKSU .nomount](https://github.com/5ec1cff/KernelSU/commit/76bfccd11f4c8953b35e1342a2461f45b7d21c22)
- tries to mimic an OEM mount, like /mnt/vendor/my_bigball
- susfs can be used to hide mounts
- requires **CONFIG_OVERLAY_FS=y** and **CONFIG_TMPFS_XATTR=y** 
- for module devs, you can also use [this standalone script](https://github.com/backslashxx/mountify/tree/standalone-script)

## Methodology
### tmpfs mode 
1. `touch /data/adb/modules/module_id/skip_mount`
2. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
3. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
4. loops 2 and 3 for all modules
5. overlays `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin` and other folders

### ext4 sparse mode 
1. `touch /data/adb/modules/module_id/skip_mount`
2. create an ext4 sparse image, mount it on `/mnt/vendor/fake_folder_name`
3. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
4. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
5. loops 3 and 4 for all modules
6. unmounts, resizes and remounts sparse image to `/mnt/vendor/fake_folder_name`
7. overlays `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin` and other folders

## Why?
- Magic mount drastically increases mount count, making detection possible (zimperium)
- OverlayFS mounting with ext4 image upperdir is detectable due to it creating device nodes on /proc/fs, while yes ext4 /data as overlay source is possible, who uses that nowadays?
- F2FS /data as overlay source fails with native casefolding (ovl_dentry_weird), so only sdcardfs users can use /data as overlay source.
- Frankly, I dont see a way to this module mounting situation, this shit is more of a shitty band-aid

### but ext4 sparse mode creates ext4 nodes!
- this is added to accomodate something like GPU drivers
- this causes detections but YMMV.
- this is not my problem, this is a fallback, not the main recommendation.
- and yes this is basically how Official KernelSU does it.

## Usage
by default, mountify mounts all modules with a system folder. To mount specific modules only, edit config.sh


- `mountify_mounts=1` then modify modules.txt to list modules you want mounted

```
module_id
Adreno_Gpu_Driver
DisplayFeatures
ViPER4Android-RE-Fork
mountify_whiteouts
```
- `FAKE_MOUNT_NAME="my_bigball"` to set a custom fake folder name
- `mountify_use_susfs=1` to enable susfs usage (optional)
- `mountify_stop_start=1` to restart android at service (optional)

##### I need mountify to skip mounting my module!
- this is easy, add `skip_mountify` to your module's folder.
- mountify checks this on /data/adb/modules/module_name
- `[ -f /data/adb/modules/module_name/skip_mountify ]`

### Need Unmount?
- use either NoHello, Shamiko, Zygisk Assistant as umount providers
- for ReZygisk, it should just work
- for Zygisk Next, enable "Enforce DenyList"
- then edit config.sh, `MOUNT_DEVICE_NAME="KSU"`

## Limitations / Recommendations
- fails with [De-Bloater](https://github.com/sunilpaulmathew/De-Bloater), as it [uses dummy text, NOT proper whiteouts](https://github.com/sunilpaulmathew/De-Bloater/blob/cadd523f0ad8208eab31e7db51f855b89ed56ffe/app/src/main/java/com/sunilpaulmathew/debloater/utils/Utils.java#L112)
- I recommend [System App Nuker](https://github.com/ChiseWaguri/systemapp_nuker/releases) instead. It uses proper whiteouts.

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.

## Links
[Download](https://github.com/backslashxx/mountify/releases)

