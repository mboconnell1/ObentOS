BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

loader: loader.asm
	make clean
	${ASM} ${ASM_FLAGS} -o bin/loader.bin $^
	cp bin/loader.bin ${BUILD_DIR}/loader.bin

clean:
	rm -rf bin
	mkdir bin