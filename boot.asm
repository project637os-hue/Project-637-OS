; Project-637-OS Bootloader
; Entry point of the Operating System

[org 0x7c00]
KERNEL_OFFSET equ 0x1000    ; Memory address where the kernel will be loaded

[bits 16]
boot_start:
    mov [BOOT_DRIVE], dl    ; BIOS stores boot drive ID in DL
    
    ; Setup stack
    mov bp, 0x9000
    mov sp, bp

    call load_kernel        ; Load the kernel from disk
    call switch_to_pm       ; Switch to 32-bit Protected Mode
    jmp $                   ; Hang if something goes wrong

%include "gdt.asm"          ; Global Descriptor Table

load_kernel:
    mov bx, KERNEL_OFFSET   ; Destination address
    mov dh, 32              ; Number of sectors to read
    mov dl, [BOOT_DRIVE]
    mov ah, 0x02            ; BIOS read function
    mov al, dh
    mov ch, 0x00            ; Cylinder 0
    mov dh, 0x00            ; Head 0
    mov cl, 0x02            ; Start reading from sector 2
    int 0x13                ; BIOS Interrupt
    ret

[bits 32]
BEGIN_PM:
    call KERNEL_OFFSET      ; Jump to the loaded Kernel code
    jmp $

BOOT_DRIVE db 0
times 510-($-$$) db 0
dw 0xaa55                   ; Boot signature
