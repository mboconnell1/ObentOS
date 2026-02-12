OS_NAME        := obentos

# ----------------------------------------------------------------------
# Build configuration
# ----------------------------------------------------------------------
ARCH           ?= i686
BUILD          ?= release
CROSS          ?= $(ARCH)-elf

# Geometry
VOL_SECTORS    := 2880
BYTES_PER_SEC  := 512
ROOT_ENTRIES   := 64
NUM_FATS       := 2

# Directories / rootfs staging
BUILD_DIR         ?= bin
BOOT_BUILD_DIR    := $(BUILD_DIR)/boot
KERNEL_BUILD_DIR  := $(BUILD_DIR)/kernel
ROOTFS_SRC        ?= rootfs
ROOTFS_DIR        := $(BUILD_DIR)/rootfs
ROOTFS_SYNC_STAMP := $(ROOTFS_DIR)/.stamp_static
ROOTFS_STATIC_FILES := $(shell if [ -d "$(ROOTFS_SRC)" ]; then find "$(ROOTFS_SRC)" -type f; fi)

VOLUME_FAT_IMG := $(BUILD_DIR)/volume_fat.img
VOLUME_IMG     := $(BUILD_DIR)/volume.img
DISK_IMG       := $(BUILD_DIR)/$(OS_NAME).img

# Tools / flags
NASM           ?= nasm
NASM_INC       := include/boot
NASM_BIN_FLAGS := -f bin -I $(NASM_INC)
NASM_ELF_FLAGS := -f elf32 -I $(NASM_INC)

GEN_BOOT_LAYOUT := tools/gen_boot_layout.sh

CC             ?= $(CROSS)-gcc
LD             ?= $(CROSS)-ld
OBJCOPY        ?= $(CROSS)-objcopy
GDB            ?= $(CROSS)-gdb
GDBFLAGS       ?= -ex "target remote :1234"

KERNEL_STD         ?= gnu11
KERNEL_WARNINGS    := -Wall -Wextra -Wpedantic
KERNEL_PLATFORM    := -ffreestanding -fno-stack-protector -fno-pic -m32 -nostdlib
ifeq ($(BUILD),debug)
KERNEL_OPTIMISATION := -Og -g
else
KERNEL_OPTIMISATION := -O2
endif
KERNEL_CFLAGS      := $(KERNEL_PLATFORM) -std=$(KERNEL_STD) $(KERNEL_WARNINGS) $(KERNEL_OPTIMISATION)
KERNEL_CFLAGS      += -MMD -MP
KERNEL_CFLAGS      += -I include
KERNEL_LDFLAGS     := -m elf_i386 -nostdlib

BOOT_LAYOUT_INC := $(NASM_INC)/common/boot_layout.inc
ROOTFS_STAGE2   := $(ROOTFS_DIR)/STAGE2.BIN
ROOTFS_KERNEL   := $(ROOTFS_DIR)/KERNEL.BIN

include build/boot.mk
include build/kernel.mk

STAGE1_SECTORS = $(shell awk '/STAGE1_SECTORS/ {print $$3}' $(BOOT_LAYOUT_INC) 2>/dev/null)

# ----------------------------------------------------------------------
# Phony targets
# ----------------------------------------------------------------------
.PHONY: all boot kernel volume images dirs clean run run-debug gdb

all: $(DISK_IMG)

boot: $(BOOT_TARGETS)
kernel: $(KERNEL_BIN)
images: $(VOLUME_IMG) $(DISK_IMG)
volume: $(VOLUME_IMG)

dirs:
	mkdir -p $(BUILD_DIR)

# ----------------------------------------------------------------------
# RootFS population
# ----------------------------------------------------------------------

$(ROOTFS_SYNC_STAMP): $(ROOTFS_STATIC_FILES) | dirs
	rm -rf $(ROOTFS_DIR)
	mkdir -p $(ROOTFS_DIR)
	if [ -d "$(ROOTFS_SRC)" ]; then \
		cp -a $(ROOTFS_SRC)/. $(ROOTFS_DIR)/; \
	fi
	touch $@

$(ROOTFS_STAGE2): $(STAGE2_BIN) $(ROOTFS_SYNC_STAMP)
	cp $< $@

$(ROOTFS_KERNEL): $(KERNEL_BIN) $(ROOTFS_SYNC_STAMP)
	cp $< $@

# ----------------------------------------------------------------------
# FAT12 volume images
# ----------------------------------------------------------------------

$(BPB_BIN): $(VOLUME_FAT_IMG)
	dd if=$< of=$@ bs=1 skip=11 count=51 status=none

$(VOLUME_FAT_IMG): $(ROOTFS_STAGE2) $(ROOTFS_KERNEL) $(BOOT_LAYOUT_INC)
	@if [ -z "$(STAGE1_SECTORS)" ]; then \
		echo "ERROR: boot_layout.inc missing STAGE1_SECTORS"; exit 1; fi
	rm -f $@

	truncate -s $$(( $(VOL_SECTORS) * $(BYTES_PER_SEC) )) $@

	mkfs.fat -F 12 \
			 -S $(BYTES_PER_SEC) \
			 -r $(ROOT_ENTRIES) \
			 -R $$((1 + $(STAGE1_SECTORS))) \
			 -f $(NUM_FATS) \
			 -n $(OS_NAME) \
			 $@

	mcopy -i $@ -s $(ROOTFS_DIR)/* ::/

$(VOLUME_IMG): $(VOLUME_FAT_IMG) $(VBR_BIN) $(STAGE1_BIN)
	cp $(VOLUME_FAT_IMG) $@
	dd if=$(VBR_BIN) of=$@ bs=512 seek=0 conv=notrunc
	dd if=$(STAGE1_BIN) of=$@ bs=512 seek=1 count=$(STAGE1_SECTORS) conv=notrunc

# ----------------------------------------------------------------------
# Final disk image layout
# ----------------------------------------------------------------------

$(DISK_IMG): $(MBR_BIN) $(VOLUME_IMG)
	rm -f $@
	dd if=$(MBR_BIN) of=$@ bs=512 seek=0 count=1 conv=notrunc
	dd if=$(VOLUME_IMG) of=$@ bs=512 seek=1 conv=notrunc

# ----------------------------------------------------------------------
# Utilities
# ----------------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(ROOTFS_DIR)
	rm -f $(BOOT_LAYOUT_INC)

run: $(DISK_IMG)
	qemu-system-x86_64 -drive file=$(DISK_IMG),format=raw,index=0,media=disk

run-debug: $(DISK_IMG)
	qemu-system-x86_64 -drive file=$(DISK_IMG),format=raw,index=0,media=disk -s -S -serial stdio

gdb: $(KERNEL_ELF)
	$(GDB) $(GDBFLAGS) $(KERNEL_ELF)
