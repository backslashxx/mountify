# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog
## 162
- LKM: update prebuilts to 66cd4af
- LKM, scripts/post-fs-data: fix usage when kernel is on cfi

## 160
- scripts/post-fs-data: mount our own tmpfs
- scripts/post-fs-data: tweak decoy mounting
- scripts/post-fs-data: add more debug
- LKM: tests: strip debug info
- scripts: cleanup logs and sparse
- scripts: expose in-kernel umount options
- scripts/post-fs-data: nuke always when ksud nuke-ext4-sysfs is available
- webui: add umount config option
- scripts/customize: handle small config changes
- scripts/service: fixup "no modules mounted"

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)
