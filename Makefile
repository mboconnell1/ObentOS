OS_NAME = ObentOS

BOOTLOADER_DIR = src/boot
BUILD_DIR = bin

MBR_DIR = $(BOOTLOADER_DIR)/bios/mbr
VBR_DIR = $(BOOTLOADER_DIR)/bios/vbr
STAGE_1_DIR = $(BOOTLOADER_DIR)/bios/stage_1
STAGE_2_DIR = $(BOOTLOADER_DIR)/bios/stage_2

BOOT_LAYOUT_INC = include/boot/asm/boot_layout.inc

MBR_BIN = $(BUILD_DIR)/mbr.bin
VBR_BIN = $(BUILD_DIR)/vbr.bin
STAGE1_BIN = $(BUILD_DIR)/stage_1.bin
STAGE2_BIN = $(BUILD_DIR)/stage_2.bin
STAGE1_PRE_BIN = $(BUILD_DIR)/stage_1.pre.bin

GEN_LAYOUT = tools/gen_boot_layout.sh

.PHONY: all clean init build_bootloader build_img layout

init:
	make clean

all:
	make build_bootloader

# ------------------------------------------------------------------------------
# Main bootloader build
# ------------------------------------------------------------------------------
build_bootloader: $(BOOT_LAYOUT_INC)
	make -C $(MBR_DIR) mbr
	make -C $(VBR_DIR) vbr
	make -C $(STAGE_1_DIR) stage_1
	make -C $(STAGE_2_DIR) stage_2
	make build_img

# ------------------------------------------------------------------------------
# Automatically generate boot_layout.inc based on stage sizes
# ------------------------------------------------------------------------------
$(BOOT_LAYOUT_INC): $(STAGE1_PRE_BIN) $(STAGE2_BIN)
	@echo "[BUILD] Generating boot_layout.inc"
	$(GEN_LAYOUT) $(STAGE1_PRE_BIN) $(STAGE2_BIN) > $(BOOT_LAYOUT_INC)

# Pre-build stage 1 (NO_LAYOUT)
$(STAGE1_PRE_BIN):
	make -C $(STAGE_1_DIR) pre

# Stage 2 (just build normally)
$(STAGE2_BIN):
	make -C $(STAGE_2_DIR) stage_2

# --------------------------------------------------------------------
# Build the final bootable image AFTER layout generation
# --------------------------------------------------------------------
build_img:
	@echo "[BUILD] Creating boot image: $(OS_NAME).img"
	dd if=$(MBR_BIN) of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=0 count=1 conv=notrunc
	dd if=$(VBR_BIN) of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=1 count=1 conv=notrunc

	# Stage 1 starts at LBA 1 + 1 = 2 (correct)
	dd if=$(STAGE1_BIN) of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=2 count=$(shell wc -c < $(STAGE1_BIN) | awk '{print int(($$1+511)/512)}') conv=notrunc

	# Stage 2 begins right after Stage 1, layout dynamically computed
	STAGE1_SECTORS=$$(sed -n 's/STAGE1_SECTORS *equ *\([0-9]\+\)/\1/p' $(BOOT_LAYOUT_INC)); \
	STAGE2_SECTORS=$$(sed -n 's/STAGE2_SECTORS *equ *\([0-9]\+\)/\1/p' $(BOOT_LAYOUT_INC)); \
	STAGE2_LBA=$$(( 2 + $$STAGE1_SECTORS )); \
	dd if=$(STAGE2_BIN) of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=$$STAGE2_LBA count=$$STAGE2_SECTORS conv=notrunc


clean:
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)
	rm -f $(BOOT_LAYOUT_INC)
	make -C $(MBR_DIR) clean
	make -C $(VBR_DIR) clean
	make -C $(STAGE_1_DIR) clean
	make -C $(STAGE_2_DIR) clean