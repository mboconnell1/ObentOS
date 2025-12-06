[bits 16]
[org 0x8000]

        jmp     _start

; Includes
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "enable_a20.asm"
%include "fat12.asm"
%include "print_string.asm"
%include "read_disk.asm"
%include "volume.asm"

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

        mov     dl, [fs:si + boot_info_t.BootDrive]
        mov     [g_BootDrive], dl

        ; Enable A20
        PRINT_STRING MSG_ENABLING_A20
        call    a20_enable
        jc      halt
        PRINT_STRING MSG_SUCCESS

        ; Initialise FAT12 volume layout from BPB
        PRINT_STRING MSG_INIT_VOLUME
        call    volume_init_layout
        PRINT_STRING MSG_SUCCESS


        PRINT_STRING MSG_FIND_STAGE2
        mov     dl, [g_BootDrive]
        call    fat12_find_stage2_in_root
        jc      halt
        PRINT_STRING MSG_SUCCESS

        PRINT_STRING MSG_STAGE2_LDNG
        mov     dl, [g_BootDrive]
        call    fat12_load_stage2
        jc      halt
        PRINT_STRING MSG_SUCCESS

        ; Jump to loader
        PRINT_STRING MSG_STAGE2_JMPG
        mov     ax, STAGE_2_SEG
        mov     bx, STAGE_2_OFF
        push    ax
        push    bx
        retf

halt:
        PRINT_STRING MSG_HALT
        jmp     $

BPB_BytesPerSec_var     dw 0
BPB_SecPerClus_var      db 0
BPB_RsvdSecCnt_var      dw 0
BPB_NumFATs_var         db 0
BPB_RootEntCnt_var      dw 0
BPB_FATSz16_var         dw 0

RootDirSectors_var      dw 0
FirstFATSector_var      dw 0
FirstRootDirSector_var  dw 0
FirstDataSector_var     dw 0

FAT_SectorIndex_var     dw 0xFFFF       ; -1 = invalid
FAT_Buffer              times 512 db 0

ROOT_Buffer             times 512 db 0\

MSG_ENABLING_A20:       db "[STAGE 1] Enabling A20... ", 0
MSG_INIT_VOLUME:        db "[STAGE 1] Initialising volume layout... ", 0
MSG_FIND_STAGE2:        db "[STAGE 1] Searching for STAGE2.BIN... ", 0
MSG_STAGE2_LDNG:        db "[STAGE 1] Loading stage 2... ", 0
MSG_STAGE2_JMPG:        db "[STAGE 1] Jumping to stage 2... ", 13, 10, 10, 0
MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HALT:               db 13, 10, "HALT", 0