[bits 16]

%ifndef __VOLUME_ASM
%define __VOLUME_ASM

; Includes
; ------------------------------------------------------------------------------
%include "common/defs.inc"

; ------------------------------------------------------------------------------
; Globals
; ------------------------------------------------------------------------------
g_BPB_BytesPerSec       dw 0
g_BPB_SecPerClus        db 0
g_BPB_RsvdSecCnt        dw 0
g_BPB_NumFATs           db 0
g_BPB_RootEntCnt        dw 0
g_BPB_FATSz16           dw 0

g_RootDirSectors        dw 0
g_FirstFATSector        dw 0
g_FirstRootDirSector    dw 0
g_FirstDataSector       dw 0

g_BootDrive             db 0

; ------------------------------------------------------------------------------
; Helpers
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; Function: volume_init_layout
;
; Purpose:  Parse BPB and compute g_BPB_* variables
;
; Inputs:   None
;
; Outputs:  g_BPB_BytesPerSec
;           g_BPB_SecPerClus
;           g_BPB_RsvdSecCnt
;           g_BPB_NumFATs
;           g_BPB_RootEntCnt
;           g_BPB_FATSz16
;           g_RootDirSectors
;           g_FirstFATSector
;           g_FirstRootDirSector
;           g_FirstDataSector
;
; Preserves: AX, BX, CX, DX
; Clobbers:  (none)
; ------------------------------------------------------------------------------
volume_init_layout:
        push    ax
        push    bx
        push    cx
        push    dx
        push    es

        mov     ax, BOOTSECT_SEG
        mov     es, ax
        mov     bx, BOOTSECT_OFF + 11

        mov     ax, [es:bx + bpb_t.BytsPerSec]
        mov     [g_BPB_BytesPerSec], ax

        mov     al, [es:bx + bpb_t.SecPerClus]
        mov     [g_BPB_SecPerClus], al

        mov     ax, [es:bx + bpb_t.RsvdSecCnt]
        mov     [g_BPB_RsvdSecCnt], ax

        mov     al, [es:bx + bpb_t.NumFATs]
        mov     [g_BPB_NumFATs], al

        mov     ax, [es:bx + bpb_t.RootEntCnt]
        mov     [g_BPB_RootEntCnt], ax

        mov     ax, [es:bx + bpb_t.FATSz16]
        mov     [g_BPB_FATSz16], ax

        ; RootDirSectors = (RootEntCnt*32 + BytesPerSec - 1) / BytesPerSec
        mov     ax, [g_BPB_RootEntCnt]
        shl     ax, 5
        mov     cx, [g_BPB_BytesPerSec]
        add     ax, cx
        dec     ax
        xor     dx, dx
        div     cx
        mov     [g_RootDirSectors], ax

        ; FirstFATSector = RsvdSecCnt
        mov     ax, [g_BPB_RsvdSecCnt]
        mov     [g_FirstFATSector], ax

        ; FirstRootDirSector = FirstFATSector + NumFATs*FATSz
        mov     ax, [g_BPB_FATSz16]
        mov     bl, [g_BPB_NumFATs]
        xor     bh, bh
        mul     bx
        add     ax, [g_BPB_RsvdSecCnt]
        mov     [g_FirstRootDirSector], ax

        ; FirstDataSector = FirstRootDirSector + RootDirSectors
        mov     ax, [g_FirstRootDirSector]
        add     ax, [g_RootDirSectors]
        mov     [g_FirstDataSector], ax

        pop     es
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

; ------------------------------------------------------------------------------
; Function: volume_read_sector
;
; Purpose:  Read a single sector from the volume by converting a volume-relative
;           LBA to an absolute LBA.
;
; Inputs:   EAX     = volume-relative LBA
;           ES:DI   = destination buffer
;           FS      = BOOT_INFO segment
;
; Outputs:  ES:DI   = buffer filled with one sector of data
;
; Preserves: SI, EBX, CX, DX
; Clobbers:  (none)
; Notes:    Uses PartitionLBAAbs from BOOT_INFO to compute the absolute LBA.
; ------------------------------------------------------------------------------
volume_read_sector:
        push    eax
        push    ebx
        push    dx
        push    si
        push    es
        push    di
        push    cx

        mov     si, BOOT_INFO_OFF
        mov     ebx, [fs:si + boot_info_t.PartitionLBAAbs]
        add     ebx, eax

        mov     dl, [g_BootDrive]
        mov     cx, 1
        call    __read_disk

        pop     cx
        pop     di
        pop     es
        pop     si
        pop     dx
        pop     ebx
        pop     eax
        ret

%endif
