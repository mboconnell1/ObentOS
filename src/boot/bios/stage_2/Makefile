BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

stage_2: stage_2.asm
	make clean
	${ASM} ${ASM_FLAGS} -o bin/stage_2.bin $^
	cp bin/stage_2.bin ${BUILD_DIR}/stage_2.bin

clean:
	rm -rf bin
	mkdir bin