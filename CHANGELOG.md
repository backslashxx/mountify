# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog

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

## 158
- scripts: move SusFS umount logic to boot-completed stage
- scripts/customize: ban installation only on susfs 1.5.10 / 1.5.11 (#13)
- webui: fix freeze when a config is added but not available in json
- webui: setup npm
- workflows/build: add webui build step
- webui: read config from modules_update after installing mountify
- webui/js: fix config not saving

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)
