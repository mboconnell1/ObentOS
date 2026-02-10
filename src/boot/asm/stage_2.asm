[bits 16]
[org 0]

        jmp _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "e820.asm"
%include "fat12.asm"
%include "print_string.asm"
%include "read_disk.asm"
%include "volume.asm"

%define STAGE2_BASE        STAGE2_MEM
%define STAGE2_BASE_LOW    (STAGE2_BASE & 0xFFFF)
%define STAGE2_BASE_MID    ((STAGE2_BASE >> 16) & 0xFF)
%define STAGE2_BASE_HIGH   ((STAGE2_BASE >> 24) & 0xFF)
%define VGA_TEXT_MEM       0xB8000

; Code
; ------------------------------------------------------------------------------
_start:

        cli
        
        mov     ax, STAGE2_STACK_TOP_SEG
        mov     ss, ax
        mov     sp, STAGE2_STACK_TOP_OFF
        mov     bp, sp

        mov     ax, cs
        mov     ds, ax
        mov     es, ax
        
        cld
        sti
        
        mov     ax, BOOT_INFO_SEG
        mov     fs, ax
        mov     si, BOOT_INFO_OFF

        mov     dl, [fs:si + boot_info_t.BootDrive]
        mov     [g_BootDrive], dl

        PRINT_STRING MSG_E820
        call    DetectMemoryE820
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_INIT_VOLUME
        call    volume_init_layout
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_FIND_KERNEL
        mov     si, KERNEL_FILENAME
        call    fat12_find_root_file
        jc      halt
        PRINT_STRING MSG_SUCCESS

        mov     [kernel_first_cluster], bx
        mov     [kernel_file_size], eax

        PRINT_STRING MSG_KERNEL_BUF_LDNG
        mov     ax, STAGE2_KERNEL_BUF_SEG
        mov     es, ax
        mov     di, STAGE2_KERNEL_BUF_OFF

        mov     ax, [kernel_first_cluster]
        mov     esi, [kernel_file_size]

        call    fat12_load_file_chain
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_SWITCHING_PM
        cli
        mov     ax, cs                 ; BIOS calls may have clobbered DS/ES
        mov     ds, ax
        mov     es, ax
        lgdt    [gdt_descriptor]
        mov     eax, cr0
        or      eax, 1
        mov     cr0, eax

        jmp     CODE_SEG:start_protected_mode

[bits 32]
start_protected_mode:
        mov     ax, DATA_SEG
        mov     ds, ax
        mov     es, ax
        mov     fs, ax
        mov     gs, ax
        mov     ss, ax
        mov     esp, STAGE2_STACK_TOP_OFF

        mov     al, 'A'
        mov     ah, 0x0f
        mov     [VGA_TEXT_MEM - STAGE2_BASE], ax    ; DS base is STAGE2_BASE

        jmp $

halt:
        PRINT_STRING MSG_HLT
        jmp     $

; Data
; ------------------------------------------------------------------------------
gdt:
.null_descriptor:
                        dd 0
                        dd 0
.code_descriptor:
                        dw 0xffff
                        dw STAGE2_BASE_LOW
                        db STAGE2_BASE_MID
                        db 10011010b
                        db 11001111b
                        db STAGE2_BASE_HIGH
.data_descriptor:
                        dw 0xffff
                        dw STAGE2_BASE_LOW
                        db STAGE2_BASE_MID
                        db 10010010b
                        db 11001111b
                        db STAGE2_BASE_HIGH
.end:

gdt_descriptor:
                        dw gdt.end - gdt - 1
                        dd gdt + STAGE2_MEM

CODE_SEG                equ gdt.code_descriptor - gdt
DATA_SEG                equ gdt.data_descriptor - gdt


KERNEL_FILENAME:        db 'KERNEL  BIN'      ; 11 bytes

kernel_first_cluster:   dw 0
kernel_file_size:       dd 0

MSG_E820:               db "[STAGE 2] Detecting available memory... ", 0
MSG_INIT_VOLUME:        db "[STAGE 2] Initialising volume layout... ", 0
MSG_FIND_KERNEL:        db "[STAGE 2] Searching for KERNEL.BIN... ", 0
MSG_KERNEL_BUF_LDNG:    db "[STAGE 2] Loading kernel into buffer... ", 0
MSG_SWITCHING_PM:       db "[STAGE 2] Switching to protected mode...", 0

MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HLT:                db 13, 10, "HALT", 0
