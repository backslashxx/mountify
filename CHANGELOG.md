# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog
## 187
- webui/js: modular append function
- webui/js: add moutnify prefix in local storage
- webui/js: fix config not saved
- scripts: account for non-tmpfs /mnt/vendor

## 186
- scripts: handle sepolicy for ksu pr 3019
- scripts/post-fs-data: redo sparse sepolicy handling
- scripts/post-fs-data: fix ext4 image context (#25)
- scripts: fixup capability test
- scripts/service: remove log folder after boot complete

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)
