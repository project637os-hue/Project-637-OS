# Build Project-637-OS
all: os-image.bin

os-image.bin: boot.bin kernel.bin
	cat boot.bin kernel.bin > os-image.bin

boot.bin: boot.asm
	nasm boot.asm -f bin -o boot.bin

kernel.bin: kernel.o
	ld -o kernel.bin -Ttext 0x1000 kernel.o --oformat binary

kernel.o: kernel.c
	gcc -ffreestanding -c kernel.c -o kernel.o

clean:
	rm *.bin *.o
