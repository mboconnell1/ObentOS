OS_NAME        := ObentOS

# Geometry
VOL_SECTORS		:= 2880
BYTES_PER_SEC	:= 512
ROOT_ENTRIES	:= 64
NUM_FATS		:= 2

# Directories
BUILD_DIR      	:= bin
ROOTFS_DIR     	:= rootfs

# Tools
ASM            	:= nasm
ASM_INC        	:= include/boot/asm
ASM_FLAGS      	:= -f bin -I $(ASM_INC)

GEN_BOOT_LAYOUT := tools/gen_boot_layout.sh

# Sources
MBR_SRC        	:= src/boot/asm/mbr.asm
VBR_SRC        	:= src/boot/asm/vbr.asm
STAGE1_SRC     	:= src/boot/asm/stage_1.asm
STAGE2_SRC     	:= src/boot/asm/stage_2.asm

# Built artefacts
MBR_BIN        	:= $(BUILD_DIR)/boot/mbr.bin
VBR_BIN        	:= $(BUILD_DIR)/boot/vbr.bin
BPB_BIN			:= $(BUILD_DIR)/boot/bpb.bin
STAGE1_BIN     	:= $(BUILD_DIR)/boot/stage_1.bin
STAGE2_BIN    	:= $(BUILD_DIR)/boot/stage_2.bin

VOLUME_FAT_IMG	:= $(BUILD_DIR)/volume_fat.img
VOLUME_IMG   	:= $(BUILD_DIR)/volume.img
DISK_IMG       	:= $(BUILD_DIR)/$(OS_NAME).img

BOOT_LAYOUT_INC := $(ASM_INC)/boot_layout.inc
STAGE1_SECTORS = $(shell awk '/STAGE1_SECTORS/ {print $$3}' $(BOOT_LAYOUT_INC) 2>/dev/null)

ROOTFS_STAGE2 := $(ROOTFS_DIR)/STAGE2.BIN

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
	mkdir -p $(ROOTFS_DIR)

# ------------------------------------------------------------
# Assembly
# ------------------------------------------------------------

$(MBR_BIN): $(MBR_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

$(STAGE1_BIN): $(STAGE1_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

$(BOOT_LAYOUT_INC): $(STAGE1_BIN)
	$(GEN_BOOT_LAYOUT) $< > $@

$(VBR_BIN): $(VBR_SRC) $(BOOT_LAYOUT_INC) $(BPB_BIN) | dirs
	$(ASM) $(ASM_FLAGS) -I $(BUILD_DIR)/boot -o $@ $<

$(STAGE2_BIN): $(STAGE2_SRC) | dirs
	$(ASM) $(ASM_FLAGS) -o $@ $<

# ------------------------------------------------------------
# RootFS population
# ------------------------------------------------------------

$(ROOTFS_STAGE2): $(STAGE2_BIN) | dirs
	cp $< $@

# ------------------------------------------------------------
# FAT12 volume images
# ------------------------------------------------------------

$(BPB_BIN): $(VOLUME_FAT_IMG)
	dd if=$< of=$@ bs=1 skip=11 count=51 status=none

$(VOLUME_FAT_IMG): $(ROOTFS_STAGE2) $(BOOT_LAYOUT_INC)
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

	dd if=$(STAGE1_BIN) of=$@ bs=512 seek=1 conv=notrunc


# ------------------------------------------------------------
# Final disk image layout
#
#   Disk LBA 0 : MBR (partition with LBAStart = 1)
#   Disk LBA 1 : volume LBA 0 (VBR)
#   Disk LBA 2+: rest of volume (stage1, FAT, root, data)
# ------------------------------------------------------------

$(DISK_IMG): $(MBR_BIN) $(VOLUME_IMG)
	rm -f $@
	dd if=$(MBR_BIN) of=$@ bs=512 seek=0 count=1 conv=notrunc
	dd if=$(VOLUME_IMG) of=$@ bs=512 seek=1 conv=notrunc

# ------------------------------------------------------------
# Utilities
# ------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(ROOTFS_DIR)
	rm -f $(BOOT_LAYOUT_INC)

run: $(DISK_IMG)
	qemu-system-x86_64 -hda $(DISK_IMG)