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

        cld
        sti

        

        jmp $

_halt:
        PRINT_STRING MSG_HLT
        jmp     $

; Data
; ------------------------------------------------------------------------------
MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HLT:                db 13, 10, "HALT", 0