obj-m += nuke.o
ccflags-y += -g0 -Os
ccflags-y += -Wno-declaration-after-statement

MDIR := $(realpath $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
$(info -- KDIR: $(KDIR))
$(info -- MDIR: $(MDIR))

modules:
	make -C $(KDIR) M=$(MDIR) EXTRA_CFLAGS="-w" modules
clean:
	make -C $(KDIR) M=$(MDIR) clean
