[bits 16]
[org 0]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "e820.asm"
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
        
        PRINT_STRING MSG_E820
        call    DetectMemoryE820
        jc      _halt
        PRINT_STRING MSG_SUCCESS

        jmp $

_halt:
        PRINT_STRING MSG_HLT
        jmp     $

; Data
; ------------------------------------------------------------------------------
MSG_E820:               db "[STAGE 2] Detecting available memory... ", 0

MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HLT:                db 13, 10, "HALT", 0