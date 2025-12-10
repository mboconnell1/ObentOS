[bits 16]
[org 0x8000]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "enable_a20.asm"
%include "fat12.asm"
%include "print_string.asm"
%include "read_disk.asm"
%include "volume.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x8000

        cld
        sti

        mov     ax, BOOT_INFO_SEG
        mov     fs, ax
        mov     si, BOOT_INFO_OFF

        mov     dl, [fs:si + boot_info_t.BootDrive]
        mov     [g_BootDrive], dl

        PRINT_STRING MSG_ENABLING_A20
        call    a20_enable
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_INIT_VOLUME
        call    volume_init_layout
        jc      halt
        PRINT_STRING MSG_SUCCESS
       
        PRINT_STRING MSG_FIND_STAGE2
        mov     si, STAGE2_FILENAME
        call    fat12_find_root_file
        jc      halt
        PRINT_STRING MSG_SUCCESS

        mov     [stage2_first_cluster], bx
        mov     [stage2_file_size], eax

        PRINT_STRING MSG_STAGE2_LDNG
        mov     ax, STAGE_2_SEG
        mov     es, ax
        mov     di, STAGE_2_OFF

        mov     ax, [stage2_first_cluster]
        mov     esi, [stage2_file_size]

        call    fat12_load_file_chain
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_STAGE2_JMPG
        mov     ax, STAGE_2_SEG
        mov     bx, STAGE_2_OFF
        push    ax
        push    bx
        retf

halt:
        PRINT_STRING MSG_HALT
        jmp     $

; Data
; ------------------------------------------------------------------------------
STAGE2_FILENAME:        db 'STAGE2  BIN'      ; 11 bytes

stage2_first_cluster:   dw 0
stage2_file_size:       dd 0

MSG_ENABLING_A20:       db "[STAGE 1] Enabling A20... ", 0
MSG_INIT_VOLUME:        db "[STAGE 1] Initialising volume layout... ", 0
MSG_FIND_STAGE2:        db "[STAGE 1] Searching for STAGE2.BIN... ", 0
MSG_STAGE2_LDNG:        db "[STAGE 1] Loading stage 2... ", 0
MSG_STAGE2_JMPG:        db "[STAGE 1] Jumping to stage 2... ", 13, 10, 10, 0
MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HALT:               db 13, 10, "HALT", 0
