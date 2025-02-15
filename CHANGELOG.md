# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog
## 135
- scripts/whiteout_gen: use whiteouts.txt if no arg
- scripts/customize: chmod +x whiteout_gen

### 134
- scripts/customize: delete testfile for xattr fail
- scripts/post-fs-data: harden regex for dir listing
- module: add updatejson
- scripts/post-fs-data: add support for APatch litemode
- scripts/service: display nomount/litemode if enabled

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)


