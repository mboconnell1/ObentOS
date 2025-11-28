[bits 16]
[org 0x7c00]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "print_string.asm"
%include "read_disk.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, ax

        mov     [boot_drive], dl
        mov     sp, 0x7C00
        mov     bp, sp

        sti

        mov     ebx, dword 0x00000002
        mov     di, 0x8000
        mov     cx, 1

        PRINT_STRING msg_reading_ldr
        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        PRINT_STRING msg_jumping_ldr
        jmp     0x0:0x8000

_halt:
        PRINT_STRING msg_hlt
        jmp     $
        
; Data
; ------------------------------------------------------------------------------
boot_drive:             db 0

msg_reading_ldr:        db "Copying loader... ", 0
msg_jumping_ldr:        db "Jumping to loader... ", 13, 10, 10, 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

        times 510-($-$$) db 0

ExFAT_BootSignature:                    dw 0xAA55