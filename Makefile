OS_NAME = ObentOS

BOOTLOADER_DIR = src/boot
BUILD_DIR = bin

MBR_DIR = $(BOOTLOADER_DIR)/bios/mbr
VBR_DIR = $(BOOTLOADER_DIR)/bios/vbr
STAGE_1_DIR = $(BOOTLOADER_DIR)/bios/stage_1
STAGE_2_DIR = $(BOOTLOADER_DIR)/bios/stage_2

init:
	make clean

all:
	make build_bootloader

build_bootloader: 
	make -C $(MBR_DIR) mbr
	make -C $(VBR_DIR) vbr
	make -C $(STAGE_1_DIR) stage_1
	make -C $(STAGE_2_DIR) stage_2
	make build_img

build_img:
	dd if=$(BUILD_DIR)/mbr.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=0 count=1 conv=notrunc
	dd if=$(BUILD_DIR)/vbr.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=1 count=1 conv=notrunc
	dd if=$(BUILD_DIR)/stage_1.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=2 count=2 conv=notrunc
	dd if=$(BUILD_DIR)/stage_2.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=4 count=1 conv=notrunc

clean:
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)
	make -C $(MBR_DIR) clean
	make -C $(VBR_DIR) clean
	make -C $(STAGE_1_DIR) clean
	make -C $(STAGE_2_DIR) clean