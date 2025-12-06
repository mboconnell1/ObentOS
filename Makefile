# ============================================================
#  ObentOS - Top-level Makefile
#  Layout:
#    Disk:
#      LBA0              : MBR (mbr.bin)
#      LBA1..            : FAT12 volume (volume.img)
#
#    Volume (relative to partition start):
#      LBA0              : VBR (vbr.bin)
#      LBA1..N           : Stage 1 loader (stage_1.bin) in reserved sectors
#      LBA(1+N)..        : FAT / root / data
#
#  gen_boot_layout.sh computes:
#      STAGE1_REL_LBA    = 1
#      STAGE1_SECTORS    = ceil(|stage_1.bin| / 512)
# ============================================================

OS_NAME        := ObentOS

# Directories
BUILD_DIR      := bin
ROOTFS_DIR     := rootfs

# Tools
ASM            := nasm
ASM_INC        := include/boot/asm
ASM_FLAGS      := -f bin -I $(ASM_INC)

GEN_BOOT_LAYOUT := tools/gen_boot_layout.sh

# FAT12 / volume config
FAT_SECTORS    := 333

# Sources (adjust paths if needed)
MBR_SRC        := src/boot/asm/mbr.asm
VBR_SRC        := src/boot/asm/vbr.asm
STAGE1_SRC     := src/boot/asm/stage_1.asm
STAGE2_SRC     := src/boot/asm/stage_2.asm

# Built artefacts
MBR_BIN        := $(BUILD_DIR)/boot/mbr.bin
VBR_BIN        := $(BUILD_DIR)/boot/vbr.bin
STAGE1_BIN     := $(BUILD_DIR)/boot/stage_1.bin
STAGE2_BIN     := $(BUILD_DIR)/boot/stage_2.bin

VOLUME_IMG     := $(BUILD_DIR)/volume.img
DISK_IMG       := $(BUILD_DIR)/$(OS_NAME).img

# Auto-generated include for VBR (contains STAGE1_REL_LBA / STAGE1_SECTORS)
BOOT_LAYOUT_INC := $(ASM_INC)/boot_layout.inc

# File inside at the root of the FAT volume, where the MBR expects to find it
ROOTFS_STAGE2 := $(ROOTFS_DIR)/STAGE2.BIN

# Parse STAGE1_SECTORS from the generated boot_layout.inc
STAGE1_SECTORS = $(shell awk '/STAGE1_SECTORS/ {print $$3}' $(BOOT_LAYOUT_INC) 2>/dev/null)

# ------------------------------------------------------------
# Phony targets
# ------------------------------------------------------------

.PHONY: all clean run dirs images boot volume

# Default: build final disk image
all: $(DISK_IMG)

images: $(VOLUME_IMG) $(DISK_IMG)
boot:   $(MBR_BIN) $(VBR_BIN) $(STAGE1_BIN) $(STAGE2_BIN)
volume: $(VOLUME_IMG)

dirs:
	mkdir -p $(BUILD_DIR)/boot

# ------------------------------------------------------------
# Assembly
# ------------------------------------------------------------

$(MBR_BIN): $(MBR_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

$(STAGE1_BIN): $(STAGE1_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

# boot_layout.inc depends on stage_1.bin
$(BOOT_LAYOUT_INC): $(STAGE1_BIN)
	$(GEN_BOOT_LAYOUT) $< > $@

# VBR needs boot_layout.inc so it sees STAGE1_REL_LBA / STAGE1_SECTORS
$(VBR_BIN): $(VBR_SRC) $(BOOT_LAYOUT_INC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

$(STAGE2_BIN): $(STAGE2_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

# ------------------------------------------------------------
# RootFS population (what goes inside the FAT volume)
# ------------------------------------------------------------

$(ROOTFS_STAGE2): $(STAGE2_BIN) | dirs
	cp $< $@

# ------------------------------------------------------------
# FAT12 volume image
#
# 1) mkfs.fat with RsvdSecCnt = 1 + STAGE1_SECTORS
# 2) Overwrite:
#       volume LBA0          with vbr.bin
#       volume LBA1..        with stage_1.bin
# 3) Use mtools to copy rootfs/ into the FAT filesystem.
# ------------------------------------------------------------

$(VOLUME_IMG): $(VBR_BIN) $(STAGE1_BIN) $(ROOTFS_STAGE2) $(BOOT_LAYOUT_INC)
	@if [ -z "$(STAGE1_SECTORS)" ]; then \
		echo "ERROR: boot_layout.inc missing STAGE1_SECTORS"; exit 1; fi
	rm -f $@

	truncate -s $$(( $(FAT_SECTORS) * 512 )) $@

	mkfs.fat -F 12 -S 512 -s 1 -r 64 -R $$((1 + $(STAGE1_SECTORS))) -f 1 -n $(OS_NAME) $@

	mcopy -i $@ -s $(ROOTFS_DIR)/* ::/

	dd if=$(VBR_BIN)    of=$@ bs=512 seek=0 count=1 conv=notrunc
	dd if=$(STAGE1_BIN) of=$@ bs=512 seek=1 count=$(STAGE1_SECTORS) conv=notrunc


# ------------------------------------------------------------
# Final disk image layout
#
#   Disk LBA 0 : MBR (partition with LBAStart = 1)
#   Disk LBA 1 : volume LBA 0 (VBR)
#   Disk LBA 2+: rest of volume (stage1, FAT, root, data)
# ------------------------------------------------------------

$(DISK_IMG): $(MBR_BIN) $(VOLUME_IMG)
	rm -f $@
	dd if=$(MBR_BIN)   of=$@ bs=512 seek=0 count=1 conv=notrunc
	dd if=$(VOLUME_IMG) of=$@ bs=512 seek=1 conv=notrunc

# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(BOOT_LAYOUT_INC)

run: $(DISK_IMG)
	qemu-system-i386 -drive file=$(DISK_IMG),format=raw,if=ide