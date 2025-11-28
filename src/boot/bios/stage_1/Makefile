BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

stage_1: stage_1.asm
	make clean
	${ASM} ${ASM_FLAGS} -o bin/stage_1.bin $^
	cp bin/stage_1.bin ${BUILD_DIR}/stage_1.bin

clean:
	rm -rf bin
	mkdir bin