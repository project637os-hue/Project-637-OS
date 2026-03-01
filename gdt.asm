; GDT Setup for Project-637-OS
gdt_start:
    dq 0x0                  ; Null descriptor
gdt_code:
    dw 0xffff, 0x0, 0x0, 10011010b, 11001111b, 0x0
gdt_data:
    dw 0xffff, 0x0, 0x0, 10010010b, 11001111b, 0x0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

[bits 16]
switch_to_pm:
    cli                     ; Disable interrupts
    lgdt [gdt_descriptor]   ; Load GDT table
    mov eax, cr0
    or eax, 0x1             ; Set Protected Mode bit
    mov cr0, eax
    jmp 0x08:init_pm        ; Far jump to flush pipeline

[bits 32]
init_pm:
    mov ax, 0x10            ; Update segment registers
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    call BEGIN_PM
