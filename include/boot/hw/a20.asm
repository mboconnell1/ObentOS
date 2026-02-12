[bits 16]

%ifndef __ENABLE_A20_ASM
    %define __ENABLE_A20_ASM

global a20_enable
global a20_get_state

; Code
; ------------------------------------------------------------------------------
; a20_get_state
; Checks the status of the A20 line.
; Input(s):
;       None.
; Output(s):
;       AX              - Disabled = 0, enabled = 1.
a20_get_state:
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

        xor     ax, ax
        jne     .enabled
        jmp     .fin
.enabled:
        mov     ax, 1
.fin:
        pop     di
        pop     si
        pop     es
        pop     ds
        popf

        ret

; a20_enable
; Enable the A20 line via multiple methods in order of least "risk".
; Input(s):
;       None.
; Output(s):
;       CF              - Set on error.
a20_enable:
        clc
        pusha
        mov     bl, 3

        call    a20_get_state
        test    ax, ax
        jnz     .fin
        jmp     .try_bios
.bios_failed:
        call    __a20_query_bios_support
        jc      .bios_support_default
        mov     bl, al
        jmp     .bios_support_mask
.bios_support_default:
        mov     bl, 3
.bios_support_mask:
        test    bl, 1
        jnz     .try_kbc
.kbc_failed:
        test    bl, 2
        jnz     .set_fast_gate
        jmp     .err
.try_bios:
        mov     ax, 0x2401
        int     0x15
        jc      .try_kbc

        call    a20_get_state
        test    ax, ax
        jnz     .fin
        jmp     .bios_failed
.try_kbc:
        call    __a20_enable_via_kbc
        call    a20_get_state
        test    ax, ax
        jnz     .fin
        jmp     .kbc_failed
.set_fast_gate:
        in      al, 0x92
        test    al, 2
        jnz     .fin

        or      al, 2
        and     al, 0xFE
        out     0x92, al

        call    a20_get_state
        test    ax, ax
        jnz     .fin
        jmp     .err
.err:
        stc
.fin:
        popa
        ret

; __a20_enable_via_kbc
; Enable the A20 line via the keyboard controller.
; Input(s):
;       None.
; Output(s):
;       None.
__a20_enable_via_kbc:
        pushf
        cli
.main:
        call    .wait_input_empty
        mov     al, 0xAD
        out     0x64, al

        call    .wait_input_empty
        mov     al, 0xD0
        out     0x64, al

        call    .wait_output_full
        in      al, 0x60
        push    ax

        call    .wait_input_empty
        mov     al, 0xD1
        out     0x64, al

        call    .wait_input_empty
        pop     ax
        or      al, 2
        out     0x60, al

        call    .wait_input_empty
        mov     al, 0xAE
        out     0x64, al

        call    .wait_input_empty
        jmp     .fin
.wait_input_empty:
        in      al, 0x64
        test    al, 2
        jnz     .wait_input_empty
        ret
.wait_output_full:
        in      al, 0x64
        test    al, 1
        jz     .wait_output_full
        ret
.fin:
        popf
        ret

; __a20_query_bios_support
; Query BIOS for A20 support.
; Input(s):
;       None.
; Output(s):
;       AX              - Bit #0 = supported on keyboard controller,
;                         bit #1 = supported with 0x92.
;       CF              - Set on error.
__a20_query_bios_support:
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
        xor     ax, ax
        stc
.fin:
        pop     bx
        ret

%endif