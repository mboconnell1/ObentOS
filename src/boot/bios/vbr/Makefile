BUILD_DIR = ../../../../bin
ASM = nasm
ASM_FLAGS = -f bin -i ../../../../include/boot/asm

vbr: vbr.asm
	make clean
	${ASM} ${ASM_FLAGS} -o bin/vbr.bin $^
	cp bin/vbr.bin ${BUILD_DIR}/vbr.bin

clean:
	rm -rf bin
	mkdir bin