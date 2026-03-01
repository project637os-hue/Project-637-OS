# Project-637-OS v0.1
**Experimental x86 Operating System by project637os-hue**

## Introduction
Project-637-OS is a real-world low-level development project for the x86 architecture. It features a custom bootloader, GDT initialization, and a functional C kernel.

## File Structure
* **boot.asm**: 16-bit bootloader that loads the kernel.
* **gdt.asm**: Global Descriptor Table for 32-bit mode.
* **io.c**: Basic hardware port communication.
* **kernel.c**: Main OS logic and VGA text output.
* **Makefile**: Automation script for building the OS image.
* **LICENSE**: Project is under the MIT License.

## Build and Run
To compile the project, use the provided Makefile:
```bash
make
To run the OS in QEMU:qemu-system-i386 -drive format=raw,file=project637-os.bin
Developed by project637os-hue (2026). This is a real software engineering project.
