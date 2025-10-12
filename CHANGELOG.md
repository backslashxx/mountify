# Mountify
Globally mounted modules and whiteouts via OverlayFS.

## Changelog
## 155
- scripts/post-fs-data: allow bypassing folder check
- scripts: add expert.sh for post-fs-data scripting support
- scripts: use generated list for susfs umount
- LKM: add README
- module/lkm: import pre-builts
- scripts: handle config and insmod for nuke.ko
- workflows: fixup for 6.12 tests
- scripts/post-fs-data: move nuking to post-fs-data
- scripts: move nuking via ksud to after-post-fs-data
- scripts/after-post-fs-data: add oplus workaround
- scripts/after-post-fs-data: prevent double umount
- webui: temp fixes so webui can be used
- LKM: remove kprobe requirement
- module/lkm: import pre-builts
- scripts/post-fs-data: perform lkm nuke with new params
- LKM/readme: link older version
- README: state licensing
- scripts/post-fs-data: add debug on LKM load
- scripts/config: fix LKM support comment
- webui: properly expose nuke lkm config
- scripts/customize: dont migrate scripts from older versions
- README: reflect recent changes

### Full Changelog
- [Commit history](https://github.com/backslashxx/mountify/commits/master/)
