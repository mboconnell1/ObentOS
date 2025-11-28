[bits 16]

%ifndef __READ_DISK_ASM
    %define __READ_DISK_ASM

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"

; Code
; ------------------------------------------------------------------------------
; __read_disk
; Check for functionality and copy sectors to another area of memory.
; Input(s):
;       CX              - Number of sectors to read.
;       DL              - BIOS-assigned disk identifier.
;       EBX             - Absolute LBA address to read from.
;       ES:DI           - Pointer to destination buffer.
; Output(s):
;       Success:
;           ES:DI       - Copy of CX sectors from EBX.
;       Failure:
;           CF          - Set on error.
;           AX          - 1 = extensions unsupported,
;                         2 = disk read error.
__read_disk:
    clc
    pusha
.main:
    mov     word [daps + daps_t.SectorsToTransfer], cx
    mov     word [daps + daps_t.BufferAddrOffset], di
    mov     word [daps + daps_t.BufferAddrSegment], es
    mov     dword [daps + daps_t.LBAAddrLow], ebx
    mov     dword [daps + daps_t.LBAAddrHigh], 0

    mov     ah, 0x41
    mov     bx, 0x55AA
    int     0x13
    jc      .err_ext_not_supp

    mov     si, daps
    mov     ah, 0x42
    int     0x13
    jc      .err_disk_read
.fin:
    popa
    ret
.err_ext_not_supp:
    mov     ax, 1
    stc
    jmp     .fin
.err_disk_read:
    mov     ax, 2
    stc
    jmp     .fin


; Data
; ------------------------------------------------------------------------------
daps:
        db 0x10
	    db 0
        dw 0
        dw 0
	    dw 0
        dd 0
	    dd 0

%endif