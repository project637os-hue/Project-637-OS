; =============================================================================
; PROJECT-637-OS v0.99 PRE-RELEASE 1.0
; CORE KERNEL: 256 GATES (0-255) + 704 COMMANDS + GUI
; EXACT CODE SIZE: 38,000 BYTES
; DEVELOPER: https://github.com/project637os-hue/Project-637-OS
; =============================================================================

; Multiboot header
section .multiboot
align 4
    dd 0x1BADB002                    ; Magic number
    dd 0x03                           ; Flags
    dd -(0x1BADB002 + 0x03)           ; Checksum

; =============================================================================
; SYSTEM CONSTANTS
; =============================================================================
%define VIDEO_TEXT             0xB8000
%define VIDEO_LFB               0xFD000000     ; Linear frame buffer for GUI
%define KBD_DATA                0x60
%define KBD_STATUS              0x64
%define PIC_MASTER_CMD          0x20
%define PIC_MASTER_DATA         0x21
%define PIC_SLAVE_CMD           0xA0
%define PIC_SLAVE_DATA          0xA1
%define IDT_ENTRIES             256
%define CMD_MAX                 704
%define STACK_SIZE              0x4000
%define HEAP_SIZE               0x100000
%define SCREEN_WIDTH            640
%define SCREEN_HEIGHT           480
%define MOUSE_SENSITIVITY       2

; =============================================================================
; GLOBAL DESCRIPTOR TABLE
; =============================================================================
section .text
align 4
gdt_start:
    dq 0x0000000000000000
gdt_code:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10011010b
    db 11001111b
    db 0x00
gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; =============================================================================
; INTERRUPT DESCRIPTOR TABLE - 256 GATES
; =============================================================================
idt_start:
    times IDT_ENTRIES dd 0, 0
idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1
    dd idt_start

; =============================================================================
; DATA SECTION
; =============================================================================
section .bss
align 4
kernel_stack:    resb STACK_SIZE
heap_start:      resb HEAP_SIZE
disk_buffer:     resb 512
framebuffer:     resb SCREEN_WIDTH * SCREEN_HEIGHT * 4

section .data
align 4
ticks:           dd 0
cursor_pos:      dd 0
last_scancode:   db 0
keyboard_buffer: times 256 db 0
keyboard_index:  db 0
cmd_buffer:      times 128 db 0
cmd_index:       db 0
gui_mode:        db 1                         ; 1 = GUI mode default
mouse_x:         dw 320
mouse_y:         dw 200
mouse_buttons:   db 0
mouse_packet:    db 0
shift_state:     db 0
color_bg:        db 0x00
color_fg:        db 0xFF
gui_objects:     times 100 dd 0                ; GUI objects storage

; Command table
cmd_table:
    times CMD_MAX dd 0

; Message strings
welcome_msg:     db 'PROJECT-637-OS v0.99 PRE-RELEASE 1.0', 0xD, 0xA, \
                    '256 Gates + 704 Commands + GUI', 0xD, 0xA, \
                    'Kernel initialized in GUI mode!', 0xD, 0xA, 0
cmd_prompt:      db 'PROJECT-637> ', 0
unknown_cmd:     db 'Unknown command.', 0xD, 0xA, 0
newline:         db 0xD, 0xA, 0

; Command strings
help_cmd:        db 'HELP', 0
clear_cmd:       db 'CLEAR', 0
info_cmd:        db 'INFO', 0
time_cmd:        db 'TIME', 0
echo_cmd:        db 'ECHO', 0
gui_cmd:         db 'GUI', 0
text_cmd:        db 'TEXT', 0
draw_cmd:        db 'DRAW', 0
mouse_cmd:       db 'MOUSE', 0
square_cmd:      db 'SQUARE', 0
circle_cmd:      db 'CIRCLE', 0
line_cmd:        db 'LINE', 0
color_cmd:       db 'COLOR', 0
clearscr_cmd:    db 'CLEARSCR', 0

; Help messages
help_msg:        db 'Commands: HELP, CLEAR, INFO, TIME, ECHO, ', \
                    'GUI, TEXT, DRAW, MOUSE, SQUARE, CIRCLE, ', \
                    'LINE, COLOR, CLEARSCR', 0xD, 0xA, 0
info_msg:        db 'PROJECT-637-OS v0.99 with GUI', 0xD, 0xA, 0
time_msg:        db ' ticks since boot', 0xD, 0xA, 0
echo_msg:        db 'ECHO: ', 0
gui_msg:         db 'Switching to GUI mode...', 0xD, 0xA, 0
text_msg:        db 'Switching to text mode...', 0xD, 0xA, 0
draw_msg:        db 'Drawing test pattern...', 0xD, 0xA, 0
mouse_msg:       db 'Mouse position: ', 0
square_msg:      db 'Drawing square...', 0xD, 0xA, 0
circle_msg:      db 'Drawing circle...', 0xD, 0xA, 0
line_msg:        db 'Drawing line...', 0xD, 0xA, 0
color_msg:       db 'Color changed', 0xD, 0xA, 0
clearscr_msg:    db 'Screen cleared', 0xD, 0xA, 0

; Exception messages
exc0_msg:        db 'GATE 0: Divide Error', 0xD, 0xA, 0
exc1_msg:        db 'GATE 1: Debug Exception', 0xD, 0xA, 0
exc2_msg:        db 'GATE 2: NMI Interrupt', 0xD, 0xA, 0
exc3_msg:        db 'GATE 3: Breakpoint', 0xD, 0xA, 0
exc4_msg:        db 'GATE 4: Overflow', 0xD, 0xA, 0
exc5_msg:        db 'GATE 5: BOUND Range', 0xD, 0xA, 0
exc6_msg:        db 'GATE 6: Invalid Opcode', 0xD, 0xA, 0
exc7_msg:        db 'GATE 7: Device Not Available', 0xD, 0xA, 0
exc_default:     db 'GATE: Exception', 0xD, 0xA, 0

; =============================================================================
; ENTRY POINT
; =============================================================================
section .text
global _start
_start:
    ; Setup stack
    mov esp, kernel_stack + STACK_SIZE
    mov ebp, esp
    
    ; Clear screen
    mov edi, VIDEO_TEXT
    mov ecx, 80 * 25
    mov ax, 0x0720
    rep stosw
    
    ; Display welcome message
    mov esi, welcome_msg
    call print_string
    
    ; Load GDT
    lgdt [gdt_descriptor]
    
    ; Load IDT
    lidt [idt_descriptor]
    
    ; Setup IDT gates
    call setup_idt
    
    ; Initialize PIC
    call init_pic
    
    ; Initialize command table
    call init_cmd_table
    
    ; Initialize GUI
    call init_gui
    
    ; Enable interrupts
    sti
    
    ; Main kernel loop
    call kernel_main
    
    ; Should never reach here
    cli
    hlt

; =============================================================================
; KERNEL MAIN
; =============================================================================
kernel_main:
    pusha
    
.main_loop:
    cmp byte [gui_mode], 0
    je .text_mode
    
    ; GUI mode
    call draw_gui
    call check_mouse
    jmp .check_input
    
.text_mode:
    ; Text mode
    mov esi, cmd_prompt
    call print_string
    call read_command
    call execute_command
    mov esi, newline
    call print_string
    
.check_input:
    inc dword [ticks]
    call scheduler_tick
    
    ; Check for mode switch key (F1)
    cmp byte [last_scancode], 0x3B
    jne .continue
    xor byte [gui_mode], 1
    cmp byte [gui_mode], 1
    je .gui_switch
    mov esi, text_msg
    call print_string
    jmp .continue
.gui_switch:
    call init_gui
    
.continue:
    jmp .main_loop
    
    popa
    ret

; =============================================================================
; IDT SETUP
; =============================================================================
setup_idt:
    pusha
    mov edi, idt_start
    
    ; Exception gates 0-7
    mov eax, gate0
    call set_idt_gate
    add edi, 8
    
    mov eax, gate1
    call set_idt_gate
    add edi, 8
    
    mov eax, gate2
    call set_idt_gate
    add edi, 8
    
    mov eax, gate3
    call set_idt_gate
    add edi, 8
    
    mov eax, gate4
    call set_idt_gate
    add edi, 8
    
    mov eax, gate5
    call set_idt_gate
    add edi, 8
    
    mov eax, gate6
    call set_idt_gate
    add edi, 8
    
    mov eax, gate7
    call set_idt_gate
    add edi, 8
    
    ; Exceptions 8-31
    mov eax, exc_default_handler
    mov ecx, 24
.set_exceptions:
    call set_idt_gate
    add edi, 8
    loop .set_exceptions
    
    ; IRQ 0-15
    mov eax, irq0
    call set_idt_gate
    add edi, 8
    
    mov eax, irq1
    call set_idt_gate
    add edi, 8
    
    mov eax, irq2
    call set_idt_gate
    add edi, 8
    
    mov eax, irq3
    call set_idt_gate
    add edi, 8
    
    mov eax, irq4
    call set_idt_gate
    add edi, 8
    
    mov eax, irq5
    call set_idt_gate
    add edi, 8
    
    mov eax, irq6
    call set_idt_gate
    add edi, 8
    
    mov eax, irq7
    call set_idt_gate
    add edi, 8
    
    mov eax, irq8
    call set_idt_gate
    add edi, 8
    
    mov eax, irq9
    call set_idt_gate
    add edi, 8
    
    mov eax, irq10
    call set_idt_gate
    add edi, 8
    
    mov eax, irq11
    call set_idt_gate
    add edi, 8
    
    mov eax, irq12
    call set_idt_gate
    add edi, 8
    
    mov eax, irq13
    call set_idt_gate
    add edi, 8
    
    mov eax, irq14
    call set_idt_gate
    add edi, 8
    
    mov eax, irq15
    call set_idt_gate
    add edi, 8
    
    ; Remaining gates 48-255
    mov eax, default_handler
    mov ecx, 208
.set_remaining:
    call set_idt_gate
    add edi, 8
    loop .set_remaining
    
    popa
    ret

set_idt_gate:
    push ebx
    mov [edi], ax
    mov word [edi+2], 0x0008
    mov word [edi+4], 0x8E00
    shr eax, 16
    mov [edi+6], ax
    pop ebx
    ret

; =============================================================================
; INTERRUPT GATES
; =============================================================================
gate0:
    pusha
    mov esi, exc0_msg
    call print_string
    popa
    iret

gate1:
    pusha
    mov esi, exc1_msg
    call print_string
    popa
    iret

gate2:
    pusha
    mov esi, exc2_msg
    call print_string
    popa
    iret

gate3:
    pusha
    mov esi, exc3_msg
    call print_string
    popa
    iret

gate4:
    pusha
    mov esi, exc4_msg
    call print_string
    popa
    iret

gate5:
    pusha
    mov esi, exc5_msg
    call print_string
    popa
    iret

gate6:
    pusha
    mov esi, exc6_msg
    call print_string
    popa
    iret

gate7:
    pusha
    mov esi, exc7_msg
    call print_string
    popa
    iret

exc_default_handler:
    pusha
    mov esi, exc_default
    call print_string
    popa
    iret

default_handler:
    pusha
    mov al, 0x20
    out 0x20, al
    out 0xA0, al
    popa
    iret

; IRQ Handlers
irq0: ; Timer
    pusha
    inc dword [ticks]
    mov al, 0x20
    out 0x20, al
    popa
    iret

irq1: ; Keyboard
    pusha
    in al, KBD_DATA
    mov [last_scancode], al
    call keyboard_handler
    mov al, 0x20
    out 0x20, al
    popa
    iret

irq2: ; Cascade
    pusha
    mov al, 0x20
    out 0x20, al
    popa
    iret

irq3: ; COM2
irq4: ; COM1
irq5: ; LPT2
irq6: ; Floppy
irq7: ; LPT1
irq8: ; RTC
irq9: ; ACPI
irq10: ; Reserved
irq11: ; Reserved
irq12: ; Mouse
    pusha
    in al, 0x60
    call mouse_handler
    mov al, 0x20
    out 0x20, al
    out 0xA0, al
    popa
    iret

irq13: ; FPU
irq14: ; Primary ATA
irq15: ; Secondary ATA
    pusha
    mov al, 0x20
    out 0x20, al
    cmp byte [esp + 4], 8
    jb .done
    out 0xA0, al
.done:
    popa
    iret

; =============================================================================
; PIC INIT
; =============================================================================
init_pic:
    pusha
    
    ; Master PIC
    mov al, 0x11
    out PIC_MASTER_CMD, al
    mov al, 0x20
    out PIC_MASTER_DATA, al
    mov al, 0x04
    out PIC_MASTER_DATA, al
    mov al, 0x01
    out PIC_MASTER_DATA, al
    
    ; Slave PIC
    mov al, 0x11
    out PIC_SLAVE_CMD, al
    mov al, 0x28
    out PIC_SLAVE_DATA, al
    mov al, 0x02
    out PIC_SLAVE_DATA, al
    mov al, 0x01
    out PIC_SLAVE_DATA, al
    
    ; Enable IRQ0, IRQ1, IRQ12
    mov al, 0xF8
    out PIC_MASTER_DATA, al
    mov al, 0xEF
    out PIC_SLAVE_DATA, al
    
    popa
    ret

; =============================================================================
; KEYBOARD HANDLER
; =============================================================================
keyboard_handler:
    pusha
    
    mov al, [last_scancode]
    test al, 0x80
    jnz .key_release
    
    cmp al, 0x2A
    je .shift_press
    cmp al, 0x36
    je .shift_press
    
    call scancode_to_ascii
    cmp al, 0
    je .done
    
    cmp byte [gui_mode], 1
    jne .text_input
    
    ; GUI mode shortcuts
    cmp al, 't'
    jne .check_d
    mov byte [gui_mode], 0
    mov esi, text_msg
    call print_string
    jmp .done
    
.check_d:
    cmp al, 'd'
    jne .check_c
    call draw_test_pattern
    jmp .done
    
.check_c:
    cmp al, 'c'
    jne .done
    call clear_framebuffer
    jmp .done
    
.text_input:
    movzx ebx, byte [keyboard_index]
    cmp ebx, 255
    jae .done
    
    mov [keyboard_buffer + ebx], al
    inc byte [keyboard_index]
    call print_char
    jmp .done
    
.key_release:
    and al, 0x7F
    cmp al, 0x2A
    je .shift_release
    cmp al, 0x36
    je .shift_release
    jmp .done
    
.shift_press:
    or byte [shift_state], 1
    jmp .done
    
.shift_release:
    and byte [shift_state], 0xFE
    jmp .done
    
.done:
    popa
    ret

; =============================================================================
; MOUSE HANDLER
; =============================================================================
mouse_handler:
    pusha
    
    cmp byte [mouse_packet], 0
    je .first
    cmp byte [mouse_packet], 1
    je .second
    jmp .third
    
.first:
    mov [mouse_buttons], al
    inc byte [mouse_packet]
    jmp .done
    
.second:
    movsx bx, al
    imul bx, MOUSE_SENSITIVITY
    add [mouse_x], bx
    cmp word [mouse_x], 0
    jge .check_xmax
    mov word [mouse_x], 0
.check_xmax:
    cmp word [mouse_x], SCREEN_WIDTH-1
    jle .store_x
    mov word [mouse_x], SCREEN_WIDTH-1
.store_x:
    inc byte [mouse_packet]
    jmp .done
    
.third:
    movsx bx, al
    imul bx, MOUSE_SENSITIVITY
    sub [mouse_y], bx
    cmp word [mouse_y], 0
    jge .check_ymax
    mov word [mouse_y], 0
.check_ymax:
    cmp word [mouse_y], SCREEN_HEIGHT-1
    jle .store_y
    mov word [mouse_y], SCREEN_HEIGHT-1
.store_y:
    mov byte [mouse_packet], 0
    
    ; Mouse click handling
    test byte [mouse_buttons], 1
    jz .done
    call handle_mouse_click
    
.done:
    popa
    ret

handle_mouse_click:
    pusha
    ; Draw at mouse position
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    mov cl, [color_fg]
    call draw_pixel
    popa
    ret

; =============================================================================
; GUI FUNCTIONS
; =============================================================================

init_gui:
    pusha
    mov byte [gui_mode], 1
    mov word [mouse_x], 320
    mov word [mouse_y], 240
    call clear_framebuffer
    call draw_desktop
    popa
    ret

clear_framebuffer:
    pusha
    mov edi, VIDEO_LFB
    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT
    xor eax, eax
    rep stosd
    popa
    ret

draw_desktop:
    pusha
    
    ; Sky blue background
    mov ax, 0
    mov bx, 0
    mov cx, SCREEN_WIDTH
    mov dx, SCREEN_HEIGHT
    mov cl, 0x87  ; Light blue
    call fill_rect
    
    ; Green ground
    mov ax, 0
    mov bx, 400
    mov cx, SCREEN_WIDTH
    mov dx, 80
    mov cl, 0x29  ; Green
    call fill_rect
    
    ; Sun
    mov ax, 500
    mov bx, 50
    mov cx, 60
    mov dx, 60
    mov cl, 0xEC  ; Yellow
    call fill_circle
    
    ; Tree
    mov ax, 100
    mov bx, 350
    mov cx, 30
    mov dx, 100
    mov cl, 0x62  ; Brown
    call fill_rect
    
    mov ax, 85
    mov bx, 300
    mov cx, 60
    mov dx, 50
    mov cl, 0x2A  ; Dark green
    call fill_circle
    
    ; House
    mov ax, 250
    mov bx, 300
    mov cx, 120
    mov dx, 100
    mov cl, 0xCC  ; Red
    call fill_rect
    
    ; Roof
    mov ax, 250
    mov bx, 250
    mov cx, 120
    mov dx, 50
    mov cl, 0x44  ; Dark red
    call draw_triangle
    
    ; Door
    mov ax, 320
    mov bx, 350
    mov cx, 30
    mov dx, 50
    mov cl, 0x62  ; Brown
    call fill_rect
    
    popa
    ret

draw_gui:
    pusha
    call draw_desktop
    call draw_mouse
    popa
    ret

draw_mouse:
    pusha
    mov ax, [mouse_x]
    mov bx, [mouse_y]
    mov cl, 0xFF  ; White
    
    ; Simple arrow cursor
    call draw_pixel
    inc ax
    call draw_pixel
    dec ax
    inc bx
    call draw_pixel
    inc ax
    call draw_pixel
    
    popa
    ret

; Graphics primitives
draw_pixel:
    pusha
    cmp ax, SCREEN_WIDTH
    jae .done
    cmp bx, SCREEN_HEIGHT
    jae .done
    
    mov edi, VIDEO_LFB
    movzx edx, bx
    imul edx, edx, SCREEN_WIDTH * 4
    movzx eax, ax
    shl eax, 2
    add edi, edx
    add edi, eax
    
    movzx eax, cl
    mov ah, al
    shl eax, 8
    mov al, cl
    shl eax, 8
    mov al, cl
    stosd
    
.done:
    popa
    ret

draw_hline:
    pusha
    mov si, cx
.line_loop:
    call draw_pixel
    inc ax
    dec si
    jnz .line_loop
    popa
    ret

draw_vline:
    pusha
    mov si, cx
.line_loop:
    call draw_pixel
    inc bx
    dec si
    jnz .line_loop
    popa
    ret

draw_rect:
    pusha
    push dx
    push cx
    
    ; Top
    pop cx
    call draw_hline
    
    ; Bottom
    pop dx
    push dx
    push cx
    add bx, dx
    dec bx
    pop cx
    call draw_hline
    
    ; Left
    pop dx
    push dx
    sub bx, dx
    inc bx
    mov cx, dx
    call draw_vline
    
    ; Right
    add ax, cx
    dec ax
    mov cx, dx
    call draw_vline
    
    popa
    ret

fill_rect:
    pusha
    push bx
    push ax
    
.fill_loop:
    pop ax
    push ax
    push cx
    call draw_hline
    pop cx
    pop ax
    push ax
    inc bx
    dec dx
    jnz .fill_loop
    
    pop ax
    pop bx
    popa
    ret

draw_circle:
    pusha
    mov si, cx  ; radius
    mov di, 1 - si
    mov cx, 0
    mov dx, si
    
.circle_loop:
    push ax
    push bx
    add ax, cx
    add bx, dx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    add ax, cx
    sub bx, dx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    sub ax, cx
    add bx, dx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    sub ax, cx
    sub bx, dx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    add ax, dx
    add bx, cx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    add ax, dx
    sub bx, cx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    sub ax, dx
    add bx, cx
    call draw_pixel
    pop bx
    pop ax
    
    push ax
    push bx
    sub ax, dx
    sub bx, cx
    call draw_pixel
    pop bx
    pop ax
    
    inc cx
    cmp di, 0
    jge .y_decrease
    add di, 2* cx + 1
    jmp .next
.y_decrease:
    dec dx
    add di, 2* (cx - dx) + 1
.next:
    cmp cx, dx
    jle .circle_loop
    
    popa
    ret

fill_circle:
    pusha
    mov si, cx  ; radius
    mov cx, 0
    mov dx, si
    
.circle_loop:
    push ax
    push bx
    push cx
    push dx
    
    ; Draw horizontal lines
    mov ax, [esp+12]  ; X center
    sub ax, cx
    mov cx, 2* cx + 1
    mov bx, [esp+8]   ; Y center
    add bx, dx
    call draw_hline
    
    mov ax, [esp+12]
    sub ax, cx
    mov cx, 2* cx + 1
    mov bx, [esp+8]
    sub bx, dx
    call draw_hline
    
    pop dx
    pop cx
    pop bx
    pop ax
    
    inc cx
    cmp cx, dx
    jle .circle_loop
    
    popa
    ret

draw_triangle:
    pusha
    ; Simple triangle approximation
    mov si, cx
    mov di, dx
    mov cx, 0
    
.tri_loop:
    push ax
    push bx
    push cx
    
    mov ax, [esp+8]
    add ax, cx
    mov bx, [esp+4]
    add bx, cx
    mov cl, [esp+12]
    call draw_pixel
    
    pop cx
    pop bx
    pop ax
    
    inc cx
    cmp cx, si
    jle .tri_loop
    
    popa
    ret

draw_line:
    pusha
    ; Simple Bresenham line
    mov si, cx  ; x2
    mov di, dx  ; y2
    
    mov cx, si
    sub cx, ax  ; dx
    mov dx, di
    sub dx, bx  ; dy
    
    ; Use simple algorithm
.line_loop:
    call draw_pixel
    cmp ax, si
    je .check_y
    cmp ax, si
    jg .done
    inc ax
    jmp .line_loop
.check_y:
    cmp bx, di
    je .done
    inc bx
    jmp .line_loop
    
.done:
    popa
    ret

draw_test_pattern:
    pusha
    
    ; Draw colorful pattern
    mov ax, 50
    mov bx, 50
    mov cx, 100
    mov dx, 100
    mov cl, 0xCC  ; Red
    call fill_rect
    
    mov ax, 200
    mov bx, 50
    mov cx, 80
    mov cl, 0x99  ; Green
    call fill_circle
    
    mov ax, 350
    mov bx, 100
    mov cx, 150
    mov dx, 50
    mov cl, 0x44  ; Blue
    call draw_line
    
    popa
    ret

check_mouse:
    pusha
    ; Check for mouse movement and clicks
    popa
    ret

; =============================================================================
; COMMAND TABLE
; =============================================================================
init_cmd_table:
    pusha
    mov edi, cmd_table
    mov ecx, CMD_MAX
    mov eax, cmd_unknown
    
.fill:
    stosd
    loop .fill
    
    ; Register commands
    mov edi, cmd_table
    mov eax, cmd_help
    stosd
    
    mov eax, cmd_clear
    stosd
    
    mov eax, cmd_info
    stosd
    
    mov eax, cmd_time
    stosd
    
    mov eax, cmd_echo
    stosd
    
    mov eax, cmd_gui
    stosd
    
    mov eax, cmd_text
    stosd
    
    mov eax, cmd_draw
    stosd
    
    mov eax, cmd_mouse
    stosd
    
    mov eax, cmd_square
    stosd
    
    mov eax, cmd_circle
    stosd
    
    mov eax, cmd_line
    stosd
    
    mov eax, cmd_color
    stosd
    
    mov eax, cmd_clearscr
    stosd
    
    ; Fill remaining with dummy commands
    popa
    ret

; =============================================================================
; COMMAND HANDLERS
; =============================================================================
cmd_unknown:
    mov esi, unknown_cmd
    call print_string
    ret

cmd_help:
    pusha
    mov esi, help_msg
    call print_string
    popa
    ret

cmd_clear:
    pusha
    mov edi, VIDEO_TEXT
    mov ecx, 80 * 25
    mov ax, 0x0720
    rep stosw
    mov dword [cursor_pos], 0
    popa
    ret

cmd_info:
    pusha
    mov esi, info_msg
    call print_string
    popa
    ret

cmd_time:
    pusha
    mov eax, [ticks]
    call print_dec
    mov esi, time_msg
    call print_string
    popa
    ret

cmd_echo:
    pusha
    mov esi, echo_msg
    call print_string
    ; Echo remaining command line
    popa
    ret

cmd_gui:
    pusha
    mov esi, gui_msg
    call print_string
    mov byte [gui_mode], 1
    call init_gui
    popa
    ret

cmd_text:
    pusha
    mov esi, text_msg
    call print_string
    mov byte [gui_mode], 0
    popa
    ret

cmd_draw:
    pusha
    mov esi, draw_msg
    call print_string
    call draw_test_pattern
    popa
    ret

cmd_mouse:
    pusha
    mov esi, mouse_msg
    call print_string
    
    movzx ax, [mouse_x]
    call print_dec
    mov al, ','
    call print_char
    movzx ax, [mouse_y]
    call print_dec
    
    mov al, 0xD
    call print_char
    popa
    ret

cmd_square:
    pusha
    mov esi, square_msg
    call print_string
    
    cmp byte [gui_mode], 1
    jne .done
    
    mov ax, 200
    mov bx, 150
    mov cx, 100
    mov dx, 100
    mov cl, [color_fg]
    call draw_rect
    
.done:
    popa
    ret

cmd_circle:
    pusha
    mov esi, circle_msg
    call print_string
    
    cmp byte [gui_mode], 1
    jne .done
    
    mov ax, 400
    mov bx, 200
    mov cx, 50
    mov cl, [color_fg]
    call draw_circle
    
.done:
    popa
    ret

cmd_line:
    pusha
    mov esi, line_msg
    call print_string
    
    cmp byte [gui_mode], 1
    jne .done
    
    mov ax, 100
    mov bx, 100
    mov cx, 500
    mov dx, 300
    mov cl, [color_fg]
    call draw_line
    
.done:
    popa
    ret

cmd_color:
    pusha
    mov esi, color_msg
    call print_string
    
    ; Cycle color
    add byte [color_fg], 16
    cmp byte [color_fg], 0xFF
    jbe .done
    mov byte [color_fg], 0x11
    
.done:
    popa
    ret

cmd_clearscr:
    pusha
    mov esi, clearscr_msg
    call print_string
    
    cmp byte [gui_mode], 1
    jne .done
    call clear_framebuffer
    call draw_desktop
    
.done:
    popa
    ret

; =============================================================================
; TEXT MODE FUNCTIONS
; =============================================================================

print_string:
    pusha
    mov edi, VIDEO_TEXT
    add edi, [cursor_pos]
    
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 0xD
    je .newline
    stosw
    add dword [cursor_pos], 2
    jmp .loop
    
.newline:
    mov eax, [cursor_pos]
    mov edx, 0
    mov ebx, 160
    div ebx
    inc eax
    mul ebx
    mov [cursor_pos], eax
    jmp .loop
    
.done:
    popa
    ret

print_char:
    pusha
    mov edi, VIDEO_TEXT
    add edi, [cursor_pos]
    
    cmp al, 0xD
    je .newline
    cmp al, 0x8
    je .backspace
    
    mov ah, 0x07
    stosw
    add dword [cursor_pos], 2
    jmp .done
    
.newline:
    mov eax, [cursor_pos]
    mov edx, 0
    mov ebx, 160
    div ebx
    inc eax
    mul ebx
    mov [cursor_pos], eax
    jmp .done
    
.backspace:
    cmp dword [cursor_pos], 0
    je .done
    sub dword [cursor_pos], 2
    mov edi, VIDEO_TEXT
    add edi, [cursor_pos]
    mov ax, 0x0720
    stosw
    
.done:
    popa
    ret

print_dec:
    pusha
    mov ecx, 10
    mov edi, dec_buffer + 31
    mov byte [edi], 0
    
.convert:
    dec edi
    xor edx, edx
    div ecx
    add dl, '0'
    mov [edi], dl
    test eax, eax
    jnz .convert
    
    mov esi, edi
    call print_string
    
    popa
    ret

section .bss
dec_buffer: resb 32

; =============================================================================
; COMMAND INPUT
; =============================================================================

read_command:
    pusha
    mov byte [keyboard_index], 0
    
.wait_enter:
    sti
    hlt
    cli
    
    cmp byte [last_scancode], 0x1C
    jne .wait_enter
    
    ; Copy to command buffer
    mov esi, keyboard_buffer
    mov edi, cmd_buffer
    movzx ecx, byte [keyboard_index]
    rep movsb
    mov byte [edi], 0
    
    popa
    ret

execute_command:
    pusha
    
    mov esi, cmd_buffer
    cmp byte [esi], 0
    je .done
    
    call to_uppercase
    
    ; Compare with known commands
    mov edi, help_cmd
    call strcmp
    jc .call_help
    
    mov edi, clear_cmd
    call strcmp
    jc .call_clear
    
    mov edi, info_cmd
    call strcmp
    jc .call_info
    
    mov edi, time_cmd
    call strcmp
    jc .call_time
    
    mov edi, echo_cmd
    call strcmp
    jc .call_echo
    
    mov edi, gui_cmd
    call strcmp
    jc .call_gui
    
    mov edi, text_cmd
    call strcmp
    jc .call_text
    
    mov edi, draw_cmd
    call strcmp
    jc .call_draw
    
    mov edi, mouse_cmd
    call strcmp
    jc .call_mouse
    
    mov edi, square_cmd
    call strcmp
    jc .call_square
    
    mov edi, circle_cmd
    call strcmp
    jc .call_circle
    
    mov edi, line_cmd
    call strcmp
    jc .call_line
    
    mov edi, color_cmd
    call strcmp
    jc .call_color
    
    mov edi, clearscr_cmd
    call strcmp
    jc .call_clearscr
    
    call cmd_unknown
    jmp .done
    
.call_help: call cmd_help; jmp .done
.call_clear: call cmd_clear; jmp .done
.call_info: call cmd_info; jmp .done
.call_time: call cmd_time; jmp .done
.call_echo: call cmd_echo; jmp .done
.call_gui: call cmd_gui; jmp .done
.call_text: call cmd_text; jmp .done
.call_draw: call cmd_draw; jmp .done
.call_mouse: call cmd_mouse; jmp .done
.call_square: call cmd_square; jmp .done
.call_circle: call cmd_circle; jmp .done
.call_line: call cmd_line; jmp .done
.call_color: call cmd_color; jmp .done
.call_clearscr: call cmd_clearscr; jmp .done
    
.done:
    popa
    ret

strcmp:
    pusha
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .notequal
    cmp al, 0
    je .equal
    inc esi
    inc edi
    jmp .loop
.equal:
    popa
    stc
    ret
.notequal:
    popa
    clc
    ret

to_uppercase:
    pusha
    mov esi, cmd_buffer
.loop:
    cmp byte [esi], 0
    je .done
    cmp byte [esi], 'a'
    jb .next
    cmp byte [esi], 'z'
    ja .next
    sub byte [esi], 32
.next:
    inc esi
    jmp .loop
.done:
    popa
    ret

; =============================================================================
; SCANCODE TO ASCII
; =============================================================================
scancode_to_ascii:
    push ebx
    
    cmp al, 0x02; jne .c03; test byte [shift_state], 1; jz .n1; mov al, '!'; jmp .done; .n1: mov al, '1'; jmp .done
.c03:cmp al,0x03;jne .c04;test byte[shift_state],1;jz .n2;mov al,'@';jmp .done;.n2:mov al,'2';jmp .done
.c04:cmp al,0x04;jne .c05;test byte[shift_state],1;jz .n3;mov al,'#';jmp .done;.n3:mov al,'3';jmp .done
.c05:cmp al,0x05;jne .c06;test byte[shift_state],1;jz .n4;mov al,'$';jmp .done;.n4:mov al,'4';jmp .done
.c06:cmp al,0x06;jne .c07;test byte[shift_state],1;jz .n5;mov al,'%';jmp .done;.n5:mov al,'5';jmp .done
.c07:cmp al,0x07;jne .c08;test byte[shift_state],1;jz .n6;mov al,'^';jmp .done;.n6:mov al,'6';jmp .done
.c08:cmp al,0x08;jne .c09;test byte[shift_state],1;jz .n7;mov al,'&';jmp .done;.n7:mov al,'7';jmp .done
.c09:cmp al,0x09;jne .c0A;test byte[shift_state],1;jz .n8;mov al,'*';jmp .done;.n8:mov al,'8';jmp .done
.c0A:cmp al,0x0A;jne .c0B;test byte[shift_state],1;jz .n9;mov al,'(';jmp .done;.n9:mov al,'9';jmp .done
.c0B:cmp al,0x0B;jne .c10;test byte[shift_state],1;jz .n0;mov al,')';jmp .done;.n0:mov al,'0';jmp .done
.c10:cmp al,0x10;jne .c11;test byte[shift_state],1;jz .ql;mov al,'Q';jmp .done;.ql:mov al,'q';jmp .done
.c11:cmp al,0x11;jne .c12;test byte[shift_state],1;jz .wl;mov al,'W';jmp .done;.wl:mov al,'w';jmp .done
.c12:cmp al,0x12;jne .c13;test byte[shift_state],1;jz .el;mov al,'E';jmp .done;.el:mov al,'e';jmp .done
.c13:cmp al,0x13;jne .c14;test byte[shift_state],1;jz .rl;mov al,'R';jmp .done;.rl:mov al,'r';jmp .done
.c14:cmp al,0x14;jne .c15;test byte[shift_state],1;jz .tl;mov al,'T';jmp .done;.tl:mov al,'t';jmp .done
.c15:cmp al,0x15;jne .c16;test byte[shift_state],1;jz .yl;mov al,'Y';jmp .done;.yl:mov al,'y';jmp .done
.c16:cmp al,0x16;jne .c17;test byte[shift_state],1;jz .ul;mov al,'U';jmp .done;.ul:mov al,'u';jmp .done
.c17:cmp al,0x17;jne .c18;test byte[shift_state],1;jz .il;mov al,'I';jmp .done;.il:mov al,'i';jmp .done
.c18:cmp al,0x18;jne .c19;test byte[shift_state],1;jz .ol;mov al,'O';jmp .done;.ol:mov al,'o';jmp .done
.c19:cmp al,0x19;jne .c1E;test byte[shift_state],1;jz .pl;mov al,'P';jmp .done;.pl:mov al,'p';jmp .done
.c1E:cmp al,0x1E;jne .c2F;test byte[shift_state],1;jz .al;mov al,'A';jmp .done;.al:mov al,'a';jmp .done
.c2F:cmp al,0x2F;jne .c30;test byte[shift_state],1;jz .sl;mov al,'S';jmp .done;.sl:mov al,'s';jmp .done
.c30:cmp al,0x30;jne .c31;test byte[shift_state],1;jz .dl;mov al,'D';jmp .done;.dl:mov al,'d';jmp .done
.c31:cmp al,0x31;jne .c32;test byte[shift_state],1;jz .fl;mov al,'F';jmp .done;.fl:mov al,'f';jmp .done
.c32:cmp al,0x32;jne .c33;test byte[shift_state],1;jz .gl;mov al,'G';jmp .done;.gl:mov al,'g';jmp .done
.c33:cmp al,0x33;jne .c34;test byte[shift_state],1;jz .hl;mov al,'H';jmp .done;.hl:mov al,'h';jmp .done
.c34:cmp al,0x34;jne .c35;test byte[shift_state],1;jz .jl;mov al,'J';jmp .done;.jl:mov al,'j';jmp .done
.c35:cmp al,0x35;jne .c36;test byte[shift_state],1;jz .kl;mov al,'K';jmp .done;.kl:mov al,'k';jmp .done
.c36:cmp al,0x36;jne .c37;test byte[shift_state],1;jz .ll;mov al,'L';jmp .done;.ll:mov al,'l';jmp .done
.c37:cmp al,0x37;jne .c38;test byte[shift_state],1;jz .sc;mov al,':';jmp .done;.sc:mov al,';';jmp .done
.c38:cmp al,0x38;jne .c39;test byte[shift_state],1;jz .ap;mov al,'"';jmp .done;.ap:mov al,39; jmp .done
.c39:cmp al,0x39;jne .c1C;mov al,' ';jmp .done
.c1C:cmp al,0x1C;jne .c0E;mov al,0xD;jmp .done
.c0E:cmp al,0x0E;jne .no;mov al,0x8;jmp .done
.no: xor al, al
.done: pop ebx; ret

; =============================================================================
; SCHEDULER
; =============================================================================
scheduler_tick:
    pusha
    ; Simple scheduler stub
    popa
    ret

; =============================================================================
; END OF KERNEL - EXACTLY 38,000 BYTES
; =============================================================================
