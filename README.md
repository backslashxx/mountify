# Mountify

#### Globally mounted modules via OverlayFS.

- acts as a KernelSU [metamodule](https://kernelsu.org/guide/metamodule.html)
- works on APatch and Magisk too
- **CONFIG_OVERLAY_FS=y** is required 
- **CONFIG_TMPFS_XATTR=y** is highly encouraged
- tries to mimic an OEM mount, like /mnt/vendor/my_bigball
- for module devs, you can also use [this standalone script](https://github.com/backslashxx/mountify/tree/standalone-script)

## Methodology
### tmpfs mode 
#### - tmpfs backed
1. `touch /data/adb/modules/module_id/skip_mount`
2. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
3. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
4. loops 2 and 3 for all modules
5. overlays `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin` and other folders

### ext4 sparse mode 
#### - ext4-sparse-on-tmpfs backed
1. `touch /data/adb/modules/module_id/skip_mount`
2. create an ext4 sparse image, mount it on `/mnt/vendor/fake_folder_name`
3. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
4. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
5. loops 3 and 4 for all modules
6. unmounts, resizes and remounts sparse image to `/mnt/vendor/fake_folder_name`
7. overlays `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin` and other folders

## Why?
- Magic mount drastically increases mount count, making detection possible (zimperium)
- OverlayFS mounting with ext4 image upperdir is detectable due to it creating device nodes on /proc/fs, while yes ext4 /data as overlay source is possible, this is rare nowadays.
- F2FS /data as overlay source fails with native casefolding (ovl_dentry_weird), so only sdcardfs users can use /data as overlay source.
- Frankly, I dont see a way to this module mounting situation, this shit is more of a shitty band-aid

### but ext4 sparse mode creates ext4 nodes!
- this is added to accomodate something like GPU drivers
- this causes detections but YMMV.
- this is not my problem, this is a fallback, not the main recommendation.
- and yes this is basically how Official KernelSU used to do it.
- if you're on GKI 5.10+, theres an experimental LKM that nukes these nodes.
- if you're on KernelSU 22105+ this is automatically handled.

## Usage
- user-friendly config editing is available on the WebUI
- otherwise you can modify /data/adb/mountify/config.sh

### General
- by default, mountify mounts all modules with a system folder. `mountify_mounts=2`
- to mount specific modules only, edit config.sh, `mountify_mounts=1` then modify modules.txt to list modules you want mounted

```
module_id
Adreno_Gpu_Driver
DisplayFeatures
ViPER4Android-RE-Fork
mountify_whiteouts
```
- `FAKE_MOUNT_NAME="mountify"` to set a custom fake folder name
- `mountify_stop_start=1` to restart android at service (needed for certain modules)

#### tmpfs specific
- `test_decoy_mount=1` to enable testing for decoy mounts on tmpfs mode

#### ext4 specific
- `use_ext4_sparse=1` to force using ext4 mode if your setup is tmpfs_xattr capable
- `spoof_sparse=1` to try spoof sparse mount as an android service
- `FAKE_APEX_NAME="com.android.mntservice"` to customize that android service spoofed name
- `sparse_size="2048"` to set your sparse size (in MB) to whatever you want
- `enable_lkm_nuke=1` to try load an experimental LKM.
- `lkm_filename="nuke.ko"` to define LKM's filename

### Need Unmount?
- use either NeoZygisk, NoHello, ReZygisk, Zygisk Assistant
- if you use Zygisk Next, then set Denylist Policy to "Enforced" or "Unmount Only"
- then edit config.sh
   - `MOUNT_DEVICE_NAME="APatch"` if you're on APatch
   - `MOUNT_DEVICE_NAME="KSU"` if you're on KernelSU forks
   - `MOUNT_DEVICE_NAME="magisk"` if you're on Magisk
- `mountify_custom_umount=0` modify this value to enable known in-kernel umount methods.
   - NOTE: zygisk provider umount is still better, this is here as a second choice.

#### I need mountify to skip mounting my module!
- this is easy, add `skip_mountify` to your module's folder.
- mountify checks this on /data/adb/modules/module_name
- `[ -f /data/adb/modules/module_name/skip_mountify ]`

## Translations
If you want to contribute to the translation of WebUI, please refer to [i18.md](i18.md)


## Limitations / Recommendations
- fails with [De-Bloater](https://github.com/sunilpaulmathew/De-Bloater), as it [uses dummy text, NOT proper whiteouts](https://github.com/sunilpaulmathew/De-Bloater/blob/cadd523f0ad8208eab31e7db51f855b89ed56ffe/app/src/main/java/com/sunilpaulmathew/debloater/utils/Utils.java#L112)
- I recommend [System App Nuker](https://github.com/ChiseWaguri/systemapp_nuker/releases) instead. It uses proper whiteouts.

## License
- module is on [The Unlicense](https://github.com/backslashxx/mountify/blob/master/LICENSE)
- LKM is on [GPLv2](https://github.com/backslashxx/mountify/blob/master/nuke_ext4_lkm/LICENSE)
- WebUI is on [MIT](https://github.com/backslashxx/mountify/blob/master/webui/LICENSE)

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.

## Links
[Download](https://github.com/backslashxx/mountify/releases)


