[bits 16]
[org 0x8000]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "enable_a20.asm"
%include "print_string.asm"
%include "read_disk.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x8000
        mov     bp, sp

        mov     [boot_drive], dl

        sti

        mov     ebx, [stage_2_lba]
        mov     ax, 0x1000
        mov     es, ax
        xor     di, di
        mov     cx, 1

        PRINT_STRING msg_enabling_a20
        call    a20_enable
        jc      _halt
        PRINT_STRING msg_success

        PRINT_STRING msg_loading_stage_2
        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        PRINT_STRING msg_jumping_stage_2
        jmp     0x1000:0000

_halt:
        PRINT_STRING msg_hlt
        jmp     $

; Data
; ------------------------------------------------------------------------------
boot_drive:             db 0
stage_2_lba:            dd 4

msg_enabling_a20:       db "[STAGE 1] Enabling A20... ", 0
msg_loading_stage_2:    db "[STAGE 1] Loading stage 2... ", 0
msg_jumping_stage_2:    db "[STAGE 1] Jumping to stage 2... ", 13, 10, 10, 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0