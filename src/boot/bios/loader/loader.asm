[bits 16]
[org 0x8000]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "enable_a20.asm"
%include "print_string.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, ax

        sti

        PRINT_STRING msg_enabling_a20
        call    __enable_a20
        jc      _halt
        PRINT_STRING msg_success

        jmp     $
_halt:
        PRINT_STRING msg_hlt
        jmp     $

; Data
; ------------------------------------------------------------------------------
msg_enabling_a20:       db "Enabling A20 line... ", 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0