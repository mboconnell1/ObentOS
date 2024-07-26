OS_NAME = ObentOS

BOOTLOADER_DIR = src/boot
BUILD_DIR = bin

MBR_DIR = $(BOOTLOADER_DIR)/bios/mbr
VBR_DIR = $(BOOTLOADER_DIR)/bios/vbr
LOADER_DIR = $(BOOTLOADER_DIR)/bios/loader

init:
	make clean

all:
	make build_bootloader

build_bootloader: 
	make -C $(MBR_DIR) mbr
	make -C $(VBR_DIR) vbr
	make -C $(LOADER_DIR) loader
	make build_img

build_img:
	dd if=$(BUILD_DIR)/mbr.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=0 count=1
	dd if=$(BUILD_DIR)/vbr.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=1 count=1
	dd if=$(BUILD_DIR)/loader.bin of=$(BUILD_DIR)/$(OS_NAME).img bs=512 seek=2 count=1

clean:
	rm -rf $(BUILD_DIR)
	mkdir $(BUILD_DIR)
	make -C $(MBR_DIR) clean
	make -C $(VBR_DIR) clean
	make -C $(LOADER_DIR) clean