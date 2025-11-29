[bits 16]
[org 0x8000]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "enable_a20.asm"
%include "print_string.asm"
%include "read_disk.asm"

; Config
; ------------------------------------------------------------------------------
%define STAGE1_REL_LBA  1
%define STAGE1_SECTORS  2

%define STAGE2_REL_LBA  (STAGE1_REL_LBA + STAGE1_SECTORS)
%define STAGE2_SECTORS  1

; Code
; ------------------------------------------------------------------------------
_start:
        cli
        
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 0x8000

        cld
        sti

        ; BOOT_INFO in FS:SI
        mov     ax, BOOT_INFO_SEG
        mov     fs, ax
        mov     si, BOOT_INFO_OFF

        ; Enable A20
        PRINT_STRING msg_enabling_a20
        call    a20_enable
        jc      _halt
        PRINT_STRING msg_success

        ; Mark A20 enabled in flags (bit 0)
        or      byte [fs:si + boot_info_t.Flags], 0000_0001b

        ; ----------------------------------------------------------------------
        ; Describe final loader (Stage 2) in BOOT_INFO
        ; ----------------------------------------------------------------------
        ; LoaderRelLBA = STAGE2_REL_LBA
        mov     eax, STAGE2_REL_LBA
        mov     [fs:si + boot_info_t.LoaderRelLBA], eax

        ; LoaderSectors = STAGE2_SECTORS
        mov     ax, STAGE2_SECTORS
        mov     [fs:si + boot_info_t.LoaderSectors], ax

        ; LoaderSegment:Offset = 0x1000:0000
        mov     ax, 0x1000
        mov     [fs:si + boot_info_t.LoaderSegment], ax
        xor     ax, ax
        mov     [fs:si + boot_info_t.LoaderOffset], ax

        ; ----------------------------------------------------------------------
        ; Load loader according to BOOT_INFO
        ; ----------------------------------------------------------------------
        ; Compute absolute LBA
        mov     eax, [fs:si + boot_info_t.PartitionLBAAbs]
        add     eax, [fs:si + boot_info_t.LoaderRelLBA]
        mov     ebx, eax

        ; ES:DI = LoaderSegment:Offset
        mov     ax, [fs:si + boot_info_t.LoaderSegment]
        mov     es, ax
        mov     di, [fs:si + boot_info_t.LoaderOffset]

        mov     cx, [fs:si + boot_info_t.LoaderSectors]

        PRINT_STRING msg_loading_stage_2
        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        ; Jump to loader
        PRINT_STRING msg_jumping_stage_2
        mov     ax, [fs:si + boot_info_t.LoaderSegment]
        mov     bx, [fs:si + boot_info_t.LoaderOffset]
        push    ax
        push    bx
        retf

_halt:
        PRINT_STRING msg_hlt
        jmp     $

; Data
; ------------------------------------------------------------------------------
boot_drive:             db 0

msg_enabling_a20:       db "[STAGE 1] Enabling A20... ", 0
msg_loading_stage_2:    db "[STAGE 1] Loading stage 2... ", 0
msg_jumping_stage_2:    db "[STAGE 1] Jumping to stage 2... ", 13, 10, 10, 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0