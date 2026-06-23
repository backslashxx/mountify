# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog
# 202
- scripts/post-fs-data: only update when description changes
- scripts/service: dont notify module mounted repeatedly
- webui/locales: Add Japanese(ja-JP) translation (#49)

# 201
- scripts/post-fs-data: apply module description earlier
- scripts: drop MKSU .nomount support
- scripts/post-fs-data: skip sync and resize
- scripts/post-fs-data: tweak copy and mount flags
- scripts/post-fs-data: reinstate 2-stage mounts
- scripts/service: harden module.prop description update
- scripts/service: fork module description apply

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)
