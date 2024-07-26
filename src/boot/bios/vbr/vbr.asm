[bits 16]
[org 0x7c00]

; ExFAT Main Boot Sector
; ------------------------------------------------------------------------------
ExFAT_JumpBoot:
        jmp     _start
        nop
ExFAT_FileSystemName:                   db "EXFAT   "
ExFAT_MustBeZero:                       times 53 db 0
ExFAT_PartitionOffset:                  dq 0
ExFAT_VolumeLength:                     dq 0
ExFAT_FatOffset:                        dd 0
ExFAT_FatLength:                        dd 0
ExFAT_ClusterHeapOffset:                dd 0
ExFAT_ClusterCount:                     dd 0
ExFAT_FirstClusterOfRootDirectory:      dd 0
ExFAT_VolumeSerialNumber:               dd 0
ExFAT_FileSystemRevision:               dw 0
ExFAT_VolumeFlags:                      dw 0
ExFAT_BytesPerSectorShift:              db 0
ExFAT_SectorsPerClusterShift:           db 0
ExFAT_NumberOfFats:                     db 0
ExFAT_DriveSelect:                      db 0
ExFAT_PercentInUse:                     db 0
ExFAT_Reserved:                         times 7 db 0
ExFAT_BootCode:

; Macros
; ------------------------------------------------------------------------------
%macro PRINT_STRING 1
        push    bx
        mov     bx, %1
        call    __print_string
        pop     bx
%endmacro

; Includes
; ------------------------------------------------------------------------------
%include "enable_a20.asm"
%include "print_string.asm"

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

        PRINT_STRING msg_enabling_a20
        call    __enable_a20
        jc      _failed
        PRINT_STRING msg_success
        jmp $

_failed:
        PRINT_STRING msg_error
        jmp     $
        
; Data
; ------------------------------------------------------------------------------
boot_drive:             db 0

msg_enabling_a20:       db "Enabling A20 line... ", 0
msg_success:            db "Success!", 13, 10, 0
msg_error:            db "Error!", 13, 10, 0

        times 510-($-$$) db 0

ExFAT_BootSignature:                    dw 0xAA55