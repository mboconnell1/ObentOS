[bits 16]

%ifndef __PRINT_ASM
    %define __PRINT_ASM

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