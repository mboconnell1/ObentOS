[bits 16]
[org 0x7c00]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "print_string.asm"
%include "read_disk.asm"

; Config
; ------------------------------------------------------------------------------
%include "boot_layout.inc"

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x7000

        cld
        sti
        
        ; BOOT_INFO in FS:SI
        mov     ax, BOOT_INFO_SEG
        mov     fs, ax
        mov     si, BOOT_INFO_OFF

        ; Load boot drive from BOOT_INFO
        mov     dl, [fs:si + boot_info_t.BootDrive]

        ; Compute absolute LBA for stage 1
        mov     eax, [fs:si + boot_info_t.PartitionLBAAbs]
        add     eax, STAGE1_REL_LBA
        mov     ebx, eax

        ; Load stage 1 into 0000:8000
        PRINT_STRING msg_loading_stage_1
        mov     di, 0x8000
        mov     cx, STAGE1_SECTORS

        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        ; Jump to stage 1
        PRINT_STRING msg_jumping_stage_1
        jmp     0x0:0x8000

_halt:
        PRINT_STRING msg_hlt
        jmp     $
        
; Data
; ------------------------------------------------------------------------------
msg_loading_stage_1:    db "[VBR] Loading stage 1... ", 0
msg_jumping_stage_1:    db "[VBR] Jumping to stage 1... ", 13, 10, 10, 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

        times 510-($-$$) db 0

        dw 0xAA55