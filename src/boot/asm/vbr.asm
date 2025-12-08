[bits 16]
[org 0x7C00]

; --------------------------------------------------------------------------
; FAT12 boot sector header
; --------------------------------------------------------------------------

    jmp vbr_start                   ; 0x7C00: jump over BPB

    db "OBENTOS "                   ; OEM name (8 bytes)

incbin "bpb.bin"

; --------------------------------------------------------------------------
; Code
; --------------------------------------------------------------------------

%include "boot_layout.inc"
%include "defs.inc"
%include "print_string.asm"
%include "read_disk.asm"

vbr_start:

    cli
        
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7000

    cld
    sti
        
    ; BOOT_INFO must already be set up by the MBR.
    mov     ax, BOOT_INFO_SEG
    mov     fs, ax
    mov     si, BOOT_INFO_OFF

    ; Get boot drive from BOOT_INFO
    mov     dl, [fs:si + boot_info_t.BootDrive]

    ; Compute absolute LBA for stage one:
    ;   Stage1AbsLBA = PartitionLBAAbs + STAGE1_REL_LBA
    mov     eax, [fs:si + boot_info_t.PartitionLBAAbs]
    add     eax, STAGE1_REL_LBA
    mov     ebx, eax

    ; Load stage one into 0000:8000
    PRINT_STRING MSG_STAGE1_LDNG
    mov     ax, 0
    mov     es, ax
    mov     di, 0x8000
    mov     cx, STAGE1_SECTORS

    call    __read_disk
    jc      vbr_halt
    PRINT_STRING MSG_SUCCESS

    ; Jump to stage 1
    PRINT_STRING MSG_STAGE1_JMPG
    jmp     0x0:0x8000

vbr_halt:
    PRINT_STRING MSG_HALT
    jmp     $
        
MSG_STAGE1_LDNG:    db "[VBR] Loading stage 1... ", 0
MSG_STAGE1_JMPG:    db "[VBR] Jumping to stage 1... ", 13, 10, 10, 0
MSG_SUCCESS:        db "Success!", 13, 10, 0
MSG_HALT:           db 13, 10, "HALT", 0

    times 510-($-$$) db 0
    dw 0xAA55