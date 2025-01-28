# Mountify

#### Globally mounted modules and whiteouts via OverlayFS.

- mostly meant for [MKSU .nomount](https://github.com/5ec1cff/KernelSU/commit/76bfccd11f4c8953b35e1342a2461f45b7d21c22)
- tries to mimic an OEM mount, like /mnt/vendor/my_bigball
- susfs is recommended for hiding mounts
- requires **CONFIG_OVERLAY_FS=y** and **CONFIG_TMPFS_XATTR=y** 
- globally mounting huge modules is discouraged

## Methodology
### module mount
1. copies contents of `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
2. mirrors SELinux context of every file from `/data/adb/modules/module_id` to `/mnt/vendor/fake_folder_name`
3. overlay `/mnt/vendor/fake_folder_name/system/bin` to `/system/bin`
### whiteouts
1. generate whiteouts module (id: mountify_whiteouts)
2. you just mount it like via module mount above

## Why It’s Done This Way
- Magic mount drastically increases mount count, making detection possible (zimperium)
- OverlayFS mounting with ext4 image upperdir is detectable due to it creating device nodes on /proc/fs, while yes ext4 /data as overlay source is possible, who uses that nowadays?
- F2FS /data as overlay source fails with native casefolding (ovl_dentry_weird), so only sdcardfs users can use /data as overlay source.
- Frankly I dont see a way to this module mounting situation, this shit is more of a shitty band-aid 

## Usage
- edit config.sh, `mountify_mounts=1` then modify modules.txt to list modules you want mounted.

```
module_id fake_folder_name
```

- run `whiteout_gen.sh target.txt` where target.txt contains list of paths you want whited out. it has to follow magisk module hierarchy so everything has to start with "/system/"

```
/system/vendor/bin/install-recovery.sh
/system/bin/install-recovery.sh
/system/system_ext/app/MatLog
```
- for whiting out addon.d, edit config.sh, set `mountify_whiteout_addond=1` and `FAKE_ADDOND_MOUNT_NAME="fake_addond"`

## Limitations
- Whiteouts might still be hit and miss.
- /system/addon.d whiteout has to be handled specifically. `WARNING: This can have repercussions when whited out!`

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.

## Links
[Download](https://github.com/backslashxx/mountify/releases)

