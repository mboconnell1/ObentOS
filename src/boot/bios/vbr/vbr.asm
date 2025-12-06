[bits 16]
[org 0x7C00]

; --------------------------------------------------------------------------
; FAT12 boot sector header
; --------------------------------------------------------------------------

    jmp vbr_start                   ; 0x7C00: jump over BPB

    db "OBENTOS "                   ; OEM name (8 bytes)

; We include layout here so we can use STAGE1_SECTORS in the BPB.
; boot_layout.inc must contain only EQU-style constants (no code).
%include "boot_layout.inc"

; Standard FAT12 BPB

BPB_BytsPerSec:   dw 512            ; bytes per sector
BPB_SecPerClus:   db 1              ; sectors per cluster
BPB_RsvdSecCnt:   dw 1 + STAGE1_SECTORS
BPB_NumFATs:      db 1              ; 1 FAT
BPB_RootEntCnt:   dw 64             ; root dir entries
BPB_TotSec16:     dw 333            ; matches partition size
BPB_Media:        db 0xF8           ; media descriptor
BPB_FATSz16:      dw 1              ; sectors per FAT
BPB_SecPerTrk:    dw 1              ; CHS junk (placeholder)
BPB_NumHeads:     dw 1              ; CHS junk (placeholder)
BPB_HiddSec:      dd 1              ; hidden sectors before this volume
BPB_TotSec32:     dd 0              ; 0 since TotSec16 is nonzero

; Extended FAT12 BPB

BS_DrvNum:        db 0              ; BIOS drive number
BS_Reserved1:     db 0
BS_BootSig:       db 0x29           ; indicates next 3 fields are present
BS_VolID:         dd 0x12345678     ; volume serial
BS_VolLab:        db "OBENTOS VOL " ; 11 bytes
BS_FilSysType:    db "FAT12   "     ; 8 bytes

; --------------------------------------------------------------------------
; Code
; --------------------------------------------------------------------------

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
    PRINT_STRING msg_loading_stage_1
    mov     ax, 0
    mov     es, ax
    mov     di, 0x8000
    mov     cx, STAGE1_SECTORS

    call    __read_disk
    jc      vbr_halt
    PRINT_STRING msg_success

    ; Jump to stage 1
    PRINT_STRING msg_jumping_stage_1
    jmp     0x0:0x8000

vbr_halt:
    PRINT_STRING msg_hlt
    jmp     $
        
msg_loading_stage_1:    db "[VBR] Loading stage 1... ", 0
msg_jumping_stage_1:    db "[VBR] Jumping to stage 1... ", 13, 10, 10, 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

    times 510-($-$$) db 0
    dw 0xAA55