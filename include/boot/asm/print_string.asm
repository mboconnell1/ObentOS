[bits 16]

%ifndef __PRINT_STRING_ASM
    %define __PRINT_STRING_ASM

; Macros
; ------------------------------------------------------------------------------
%macro PRINT_STRING 1
        push    bx
        mov     bx, %1
        call    __print_string
        pop     bx
%endmacro

; Code
; ------------------------------------------------------------------------------
; __print_string
; Displays an ASCII string.
; Input(s):
;       BX              - Pointer to string buffer.
; Output(s):
;       None.
__print_string:
        pusha         
.loop:
        mov     al, [bx]  
        cmp     al, 0     
        je      .fin

        mov     ah, 0x0E
        int     0x10
        inc     bx
        jmp     .loop          
.fin:
        popa
        ret


%endif