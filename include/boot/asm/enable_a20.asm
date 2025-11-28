[bits 16]

%ifndef __ENABLE_A20_ASM
    %define __ENABLE_A20_ASM

; Code
; ------------------------------------------------------------------------------
; __get_a20_state
; Checks the status of the A20 line.
; Input(s):
;       None.
; Output(s):
;       AX              - Disabled = 0, enabled = 1.
__get_a20_state:
        pushf
        push    ds
        push    es
        push    si
        push    di
        cli
.main:
        xor     ax, ax
        mov     es, ax

        not     ax
        mov     ds, ax

        mov     di, 0x0500
        mov     si, 0x0510

        mov     al, byte [es:di]
        push    ax
        mov     al, byte [ds:si]
        push    ax

        mov     byte [es:di], 0x00
        mov     byte [ds:si], 0xFF
        mov     al, [es:di]
        cmp     al, [ds:si]

        pop     ax
        mov     byte [ds:si], al
        pop     ax
        mov     byte [es:di], al

        mov     ax, 0
        je      .fin
        mov     ax, 1
.fin:
        pop     di
        pop     si
        pop     es
        pop     ds
        popf

        ret

; __enable_a20
; Enable the A20 line via multiple methods in order of least "risk".
; Input(s):
;       None.
; Output(s):
;       CF              - Set on error.
__enable_a20:
        clc
        pusha
.main:
        mov     bh, 0

        call    __get_a20_state
        test    ax, ax
        jnz     .fin
        jmp     .set_bios
.err_set_bios:
        call    __query_a20_support
        mov     bl, al
        test    bl, 1
        jnz     .set_keyboard_controller
.err_set_keyboard_controller:
        test    bl, 2
        jnz     .set_fast_gate
.set_bios:
        mov     ax, 0x2401
        int     0x15
        jc      .set_keyboard_controller

        call    __get_a20_state
        test    ax, ax
        jnz     .fin
        jmp     .err_set_bios
.set_keyboard_controller:
        call    __enable_a20_keyboard_controller
        call    __get_a20_state
        test    ax, ax
        jnz     .fin
        jmp     .err_set_keyboard_controller
.set_fast_gate:
        in      al, 0x92
        test    al, 2
        jnz     .fin

        or      al, 2
        and     al, 0xFE
        out     0x92, al

        call    __get_a20_state
        test    ax, ax
        jnz     .fin
        jmp     .err
.err:
        stc
.fin:
        popa
        ret

; __enable_a20_keyboard_controller
; Enable the A20 line via the keyboard controller.
; Input(s):
;       None.
; Output(s):
;       None.
__enable_a20_keyboard_controller:
        cli
.main:
        call    .wait_io1
        mov     al, 0xAD
        out     0x64, al


        call    .wait_io1
        mov     al, 0xD0
        out     0x64, al

        call    .wait_io2
        in      al, 0x60
        push    eax

        call    .wait_io1
        mov     al, 0xD1
        out     0x64, al

        call    .wait_io1
        pop     eax
        or      al, 2
        out     0x60, al

        call    .wait_io1
        mov     al, 0xAE
        out     0x64, al

        call    .wait_io1
        jmp     .fin
.wait_io1:
        in      al, 0x64
        test    al, 2
        jnz     .wait_io1
        ret
.wait_io2:
        in      al, 0x64
        test    al, 1
        jz     .wait_io2
        ret
.fin:
        sti
        ret

; __query_a20_support
; Query BIOS for A20 support.
; Input(s):
;       None.
; Output(s):
;       AX              - Bit #0 = supported on keyboard controller,
;                         bit #1 = supported with 0x92.
;       CF              - Set on error.
__query_a20_support:
        clc
        push    bx
.main:
        mov     ax, 0x2403
        int     0x15
        jc      .err

        test    ah, ah
        jnz     .err

        mov     ax, bx
        jmp     .fin
.err:
        stc
.fin:
        pop     bx
        ret

msg_break:           db "Break!", 13, 10, 0

%endif