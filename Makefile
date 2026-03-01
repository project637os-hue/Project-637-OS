all: os-image.bin

boot.bin: Source/boot.asm
	nasm -f bin Source/boot.asm -o boot.bin

kernel.o: Source/kernel.c
	gcc -m32 -ffreestanding -c Source/kernel.c -o kernel.o

kernel.bin: kernel.o
	ld -m elf_i386 -o kernel.bin -Ttext 0x1000 kernel.o --oformat binary

os-image.bin: boot.bin kernel.bin
	cat boot.bin kernel.bin > os-image.bin

clean:
	rm -f *.bin *.o
