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

; 1 MiB is not representable as seg:off by simply shifting >> 4 because the
; segment value overflows 16 bits. Load the kernel at physical 0x0010_0000
; using the canonical 0xFFFF:0x0010 pointer.
%define KERNEL_LOAD_OFF         0x0010
%define KERNEL_LOAD_SEG         ((KERNEL_MEM - KERNEL_LOAD_OFF) >> 4)

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

        PRINT_STRING MSG_KERNEL_LDNG
        mov     ax, KERNEL_LOAD_SEG
        mov     es, ax
        mov     di, KERNEL_LOAD_OFF

        mov     ax, [kernel_first_cluster]
        mov     esi, [kernel_file_size]

        call    fat12_load_file_chain
        jc      halt
        PRINT_STRING MSG_SUCCESS

        jmp $

halt:
        PRINT_STRING MSG_HLT
        jmp     $

; Data
; ------------------------------------------------------------------------------
KERNEL_FILENAME:        db 'KERNEL  BIN'      ; 11 bytes

kernel_first_cluster:   dw 0
kernel_file_size:       dd 0

MSG_E820:               db "[STAGE 2] Detecting available memory... ", 0
MSG_INIT_VOLUME:        db "[STAGE 2] Initialising volume layout... ", 0
MSG_FIND_KERNEL:        db "[STAGE 2] Searching for KERNEL.BIN... ", 0
MSG_KERNEL_LDNG:        db "[STAGE 2] Loading kernel... ", 0

MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HLT:                db 13, 10, "HALT", 0
