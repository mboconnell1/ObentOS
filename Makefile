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

PART_SECTORS = 333
VOL_IMG      = $(BUILD_DIR)/volume.img

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
$(BOOT_LAYOUT_INC): $(STAGE1_BIN)
	@echo "[BUILD] Generating boot_layout.inc"
	$(GEN_LAYOUT) $(STAGE1_BIN) > $(BOOT_LAYOUT_INC)

$(STAGE1_BIN):
	$(MAKE) -C $(STAGE_1_DIR) stage_1

$(STAGE2_BIN):
	$(MAKE) -C $(STAGE_2_DIR) stage_2

PART_SECTORS = 333
VOL_IMG      = $(BUILD_DIR)/volume.img

build_volume: $(VBR_BIN) $(STAGE1_BIN) $(STAGE2_BIN) $(BOOT_LAYOUT_INC)
	@echo "[BUILD] Creating FAT12 volume image"

	@STAGE1_SECTORS=$$(sed -n 's/^STAGE1_SECTORS *equ *\([0-9]\+\)/\1/p' $(BOOT_LAYOUT_INC)); \
	RSVD_SEC_CNT=$$((1 + $$STAGE1_SECTORS)); \
	echo "  STAGE1_SECTORS = $$STAGE1_SECTORS"; \
	echo "  RSVD_SEC_CNT   = $$RSVD_SEC_CNT"; \
	\
	truncate -s $$(( $(PART_SECTORS) * 512 )) $(VOL_IMG); \
	\
	mkfs.fat -F 12 \
	         -S 512 \
	         -s 1 \
	         -r 64 \
	         -R $$RSVD_SEC_CNT \
			 -f 1 \
	         -n OBENTOS \
	         $(VOL_IMG); \
	\
	mcopy -i $(VOL_IMG) $(STAGE2_BIN) ::STAGE2.BIN; \
	\
	dd if=$(VBR_BIN) of=$(VOL_IMG) bs=512 seek=0 count=1 conv=notrunc; \
	dd if=$(STAGE1_BIN) of=$(VOL_IMG) bs=512 seek=1 \
	   count=$$STAGE1_SECTORS conv=notrunc

build_img: $(MBR_BIN) build_volume
	@echo "[BUILD] Creating boot image: $(OS_NAME).img"

	truncate -s $$(( (1 + $(PART_SECTORS)) * 512 )) $(BUILD_DIR)/$(OS_NAME).img

	dd if=$(MBR_BIN) of=$(BUILD_DIR)/$(OS_NAME).img \
	   bs=512 seek=0 count=1 conv=notrunc

	dd if=$(VOL_IMG) of=$(BUILD_DIR)/$(OS_NAME).img \
	   bs=512 seek=1 conv=notrunc

clean:
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)
	rm -f $(BOOT_LAYOUT_INC)
	make -C $(MBR_DIR) clean
	make -C $(VBR_DIR) clean
	make -C $(STAGE_1_DIR) clean
	make -C $(STAGE_2_DIR) clean