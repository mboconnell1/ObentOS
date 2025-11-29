BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

mbr: mbr.asm
	make clean
	$(ASM) $(ASM_FLAGS) -o bin/mbr.bin $<
	cp bin/mbr.bin $(BUILD_DIR)/mbr.bin

clean:
	rm -rf bin
	mkdir bin