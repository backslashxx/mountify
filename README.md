# Mountify

#### Globally mounted modules and whiteouts via OverlayFS.

- mostly meant for [MKSU .nomount](https://github.com/5ec1cff/KernelSU/commit/76bfccd11f4c8953b35e1342a2461f45b7d21c22)
- tries to mimic an OEM mount, like /mnt/vendor/my_bigball
- susfs is can be used to hide mounts
- requires **CONFIG_OVERLAY_FS=y** and **CONFIG_TMPFS_XATTR=y** 
- for module devs, you can also use [this standalone script](https://github.com/backslashxx/mountify/tree/standalone-script)

## Methodology
### module mount
1. `touch /data/adb/modules/module_id/skip_mount`
2. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
3. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
4. overlay `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin`
### whiteouts
1. whiteout_gen.sh will generate a module (mountify_whiteouts)
2. you just mount it like via module mount above
- alternatively you can do [this](https://kernelsu.org/guide/module.html#kernelsu-modules:~:text=You%20can%20also%20declare%20a%20variable%20named%20REMOVE) and mount it like a module

## Why It’s Done This Way
- Magic mount drastically increases mount count, making detection possible (zimperium)
- OverlayFS mounting with ext4 image upperdir is detectable due to it creating device nodes on /proc/fs, while yes ext4 /data as overlay source is possible, who uses that nowadays?
- F2FS /data as overlay source fails with native casefolding (ovl_dentry_weird), so only sdcardfs users can use /data as overlay source.
- Frankly I dont see a way to this module mounting situation, this shit is more of a shitty band-aid 

## Usage
### Module mount
by default, mountify will mount all modules with a system folder. `mountify_mounts=2` If this is not an intended behavior, edit config.sh


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

### Whiteout
- run `whiteout_gen.sh target.txt` where target.txt contains list of paths you want whited out. It has to follow magisk module hierarchy so everything has to start with "/system/". Here are some examples:

```
/system/vendor/bin/install-recovery.sh
/system/vendor/bin/msm_irqbalance
/system/bin/install-recovery.sh
/system/system_ext/app/MatLog
/system/system_ext/priv-app/AudioFX
/system/product/app/PowerOffAlarm
/system/product/app/Twelve
/system/etc/nikgapps_logs_archive
/system/etc/nikgapps_logs
/system/bin/servicemanager
```

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.

## Links
[Download](https://github.com/backslashxx/mountify/releases)


