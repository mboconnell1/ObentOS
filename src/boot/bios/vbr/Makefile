BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

vbr: vbr.asm ../../../../include/boot/asm/boot_layout.inc
	make clean
	$(ASM) $(ASM_FLAGS) -o bin/vbr.bin $<
	cp bin/vbr.bin $(BUILD_DIR)/vbr.bin

pre:
	make vbr

clean:
	rm -rf bin
	mkdir bin
