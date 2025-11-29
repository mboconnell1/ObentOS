[bits 16]
[org 0]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "print_string.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        mov     ax, cs
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0xFFFE
        mov     bp, sp

        sti

        jmp $

_halt:
        PRINT_STRING msg_hlt
        jmp     $

; Data
; ------------------------------------------------------------------------------
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0