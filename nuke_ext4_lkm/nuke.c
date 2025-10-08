#include <linux/module.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/path.h>
#include <linux/namei.h>
#include <linux/string.h>
#include <linux/kallsyms.h>

#ifndef MODULE
#error "This is for LKM builds only. Do not compile built-in (CONFIG_NUKE_EXT4_SYSFS=y). Its bullshit."
#endif

// insmod nuke.ko mount_point=/data/adb/modules

static char *mount_point = "/data/adb/modules";
module_param(mount_point, charp, 0000);
MODULE_PARM_DESC(mount_point, "nuke an ext4 sysfs node");

static void __exit nuke_exit(void) {}

static int __init nuke_entry(void)
{
	struct path path;
	void (*ext4_unregister_sysfs_fn)(struct super_block *);

	pr_info("nuke_ext4: init with mount_point=%s\n", mount_point);

	// look for ext4_unregister_sysfs
	unsigned long addr = kallsyms_lookup_name("ext4_unregister_sysfs");
	if (addr)
		pr_info("nuke_ext4: ext4_unregister_sysfs found on 0x%lx\n",addr);
	else {
		pr_info("nuke_ext4: kallsyms_lookup_name failed for ext4_unregister_sysfs\n");
		return -EAGAIN;
	}

	// kang from ksu
	int err = kern_path(mount_point, 0, &path);
	if (err) {
		pr_info("nuke_ext4: kern_path failed: %d\n", err);
		return -EAGAIN;
	}

	struct super_block* sb = path.dentry->d_inode->i_sb;
	const char* name = sb->s_type->name;
	if (strcmp(name, "ext4") != 0) {
		pr_info("nuke_ext4: not ext4\n");
		path_put(&path);
		return -EAGAIN;
	}

	// cast to its actual fn type since kallsyms_lookup_name returns long address
	// extern void ext4_unregister_sysfs(struct super_block *sb); on fs/ext4/ext4.h
	// now I have no idea how kernelsu uses it as is, this fn is not exported for LKM
	ext4_unregister_sysfs_fn = (void (*)(struct super_block *))addr;

	pr_info("nuke_ext4: unregistering sysfs node for ext4 volume (%s)\n", sb->s_id);
	ext4_unregister_sysfs_fn(sb);
	path_put(&path);

	pr_info("nuke_ext4: done, unload\n");
	return -EAGAIN;
}

module_init(nuke_entry);
module_exit(nuke_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("xx");
MODULE_DESCRIPTION("nuke ext4 sysfs");
