[bits 16]
[org 0x0600]

        jmp     _start

; Include files
; ------------------------------------------------------------------------------
%include "defs.inc"
%include "print_string.asm"
%include "read_disk.asm"

; Code
; ------------------------------------------------------------------------------
_start:
        jmp     _relocate

_relocate:
        cli
        ; Zero relevant registers.
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, ax

        ; Relocate MBR and near jump.
        mov     cx, 0x0200              ; No. of bytes to copy (512 in MBR).
        mov     si, 0x7C00              ; Current MBR address.
        mov     di, 0x0600              ; New MBR Address.
        rep     movsb                   ; Copy MBR.
        jmp     0x0:_jump

_jump:
        sti
        mov     bp, sp

        ; Initialise BOOT_INFO at 0000:7E00
        mov     ax, BOOT_INFO_SEG
        mov     es, ax
        mov     cx, boot_info_t_size
        xor     al, al
        rep     stosb

        ; BOOT_INFO.Signature = 'BI'
        mov     ax, 'BI'
        mov     [es:BOOT_INFO_OFF + boot_info_t.Signature], ax

        ; BOOT_INFO.Version = 1
        mov     byte [es:BOOT_INFO_OFF + boot_info_t.Version], 1

        ; BOOT_INFO.BootDrive = DL
        mov     [es:BOOT_INFO_OFF + boot_info_t.BootDrive], dl

        ; Check partition table for a bootable partition.
        lea     bx, [0x0600 + mbr_t.PartitionEntry1]
        mov     cx, 4
.loop:
        mov     al, byte [bx]
        test    al, 0x80                ; active flag?
        jnz     .found          
        add     bx, partition_table_entry_t_size
        dec     cx
        jnz     .loop

        jmp     .err_no_active_partition
.found:
        ; BX points to active partition entry
        ; SI points to LBAStartAddress within that entry
        mov     si, bx
        add     si, partition_table_entry_t.LBAStartAddress

        ; Store LBAStartAddess as PartitionLBAAbs in BOOT_INFO
        mov     eax, [si]
        mov     [es:BOOT_INFO_OFF + boot_info_t.PartitionLBAAbs], eax

        ; Read VBR into 0000:7C000
        mov     ebx, eax
        xor     ax, ax
        mov     es, ax
        mov     di, 0x7C00
        mov     cx, 1

        PRINT_STRING msg_reading_vbr
        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        ; Verify boot signature and jump to VBR.
        cmp     word [0x7DFE], 0xAA55
        jne     .err_partition_not_bootable

        PRINT_STRING msg_jumping_vbr
        jmp     0x0:0x7C00

.err_no_active_partition:
        PRINT_STRING msg_no_active
        jmp     _halt
        
.err_partition_not_bootable:
        PRINT_STRING msg_not_bootable
        jmp     _halt

_halt:
        PRINT_STRING msg_hlt
        jmp     $

msg_reading_vbr:        db "[MBR] Loading VBR... ", 0
msg_jumping_vbr:        db "[MBR] Jumping to VBR... ", 13, 10, 10, 0
msg_no_active:          db "Couldn't find active partition!", 0
msg_not_bootable:       db "Active partition not bootable!", 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

        times 446 - ($-$$) db 0      ; Pad remaining bootstrap space.

partition_tables:
.Partition1:
        db 0x80
        db 0x00
        dw 0x0000
        db 0x01
        db 0x00
        dw 0x0000
        dd 0x00000001
        dd 2880
.Partition2: times 16 db 0
.Partition3: times 16 db 0
.Partition4: times 16 db 0

        dw 0xAA55                      ; Boot signature.