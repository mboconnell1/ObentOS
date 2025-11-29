BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

stage_1: stage_1.asm ../../../../include/boot/asm/boot_layout.inc
	make clean
	$(ASM) $(ASM_FLAGS) -o bin/stage_1.bin $<
	cp bin/stage_1.bin $(BUILD_DIR)/stage_1.bin

# "pre" build – NO_LAYOUT is defined, boot_layout.inc is not included
pre: stage_1.asm
	make clean
	$(ASM) $(ASM_FLAGS) -DNO_LAYOUT -o bin/stage_1.pre.bin $<
	cp bin/stage_1.pre.bin $(BUILD_DIR)/stage_1.pre.bin

clean:
	rm -rf bin
	mkdir bin
