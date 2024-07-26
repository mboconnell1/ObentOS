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
msg_jumping_ldr:        db "Jumping to loader... ", 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

        times 510-($-$$) db 0

ExFAT_BootSignature:                    dw 0xAA55