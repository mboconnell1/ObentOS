[bits 16]

%ifndef __READ_DISK_ASM
    %define __READ_DISK_ASM

; Includes
; ------------------------------------------------------------------------------
%include "print_string.asm"

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
;           None.
__read_disk:
    pusha

    ; Fill DAPS.
    mov     word [daps + daps_t.SectorsToTransfer], cx
    mov     word [daps + daps_t.BufferAddrOffset], di
    mov     dword [daps + daps_t.LBAAddrLow], ebx

    ; Check for functionality.
    mov     ah, 0x41
    mov     bx, 0x55AA
    int     0x13
    jc      __read_disk_err.ext_not_supp

    mov     si, daps
    mov     ah, 0x42
    int     0x13
    jc      __read_disk_err.disk

    popa
    ret

__read_disk_err:
.ext_not_supp:
    mov     bx, msg_err_ext_not_supported
    call    __print_string
    jmp     $
.disk:
    mov     bx, msg_err_disk
    call    __print_string
    jmp     $


; Data
; ------------------------------------------------------------------------------
msg_err_ext_not_supported: db "LBA mode is not supported!", 0
msg_err_disk: db "Error reading disk!", 0

daps:
        db 0x10
	    db 0
        dw 0
        dw 0
	    dw 0
        dd 0
	    dd 0

; Structures
; ------------------------------------------------------------------------------
struc daps_t
    .PacketSize         : resb 1
    .Reserved           : resb 1
    .SectorsToTransfer  : resw 1
    .BufferAddrOffset   : resw 1
    .BufferAddrSegment  : resw 1
    .LBAAddrLow         : resw 2
    .LBAAddrHigh        : resw 2
endstruc

%endif