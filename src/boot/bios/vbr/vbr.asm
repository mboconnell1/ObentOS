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

; Code
; ------------------------------------------------------------------------------
_start:
        jmp $

; Data
; ------------------------------------------------------------------------------
times 510-($-$$) db 0

ExFAT_BootSignature:                    dw 0xAA55