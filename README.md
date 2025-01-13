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
1. generate whiteouts on `/debug_ramdisk/mountify/wo`
2. copy those whiteouts to `/mnt/vendor/whiteout`
3. overlay `/mnt/vendor/whiteout/system/bin` to `/system/bin`

## Usage
- edit config.sh, `mountify_mounts=1` then modify modules.txt to list modules you want mounted.

```
module_id fake_folder_name
```

- edit config.sh, `mountify_whiteouts=1` then modify whiteouts.txt for files you want whited out.

```
/system/bin/find
```

## Limitations
- Whiteouts tend to fail on most setups. I still do NOT know why. \<insert we just dont know gif>

## Support / Warranty
- None, none at all. I am handing you a sharp knife, it is not on me if you stab yourself with it.

## Links
[Download](https://github.com/backslashxx/mountify/releases)



