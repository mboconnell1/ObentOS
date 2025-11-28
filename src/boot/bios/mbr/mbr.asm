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

        mov     byte [boot_drive], dl   ; BIOS sets DL to "drive number".

        ; Check partition table for a bootable partition.
        lea     bx, [0x0600 + mbr_t.PartitionEntry1]
        mov     cx, 4
.loop:
        mov     al, byte [bx]
        test    al, 0x80                ; Check if marked as active.
        jnz     .found          
        add     bx, partition_table_entry_t_size
        dec     cx
        jnz     .loop
        jmp     .err_no_active_partition
.found:
        mov     word [partition_offset], bx

        ; Read VBR into 0x7C00.
        add     bx, 8                   ; Move to LBA address.
        mov     ebx, dword [bx]
        mov     di, 0x7C00
        mov     cx, 1

        PRINT_STRING msg_reading_vbr
        call    __read_disk
        jc      _halt
        PRINT_STRING msg_success

        ; Verify boot signature and jump to VBR.
        cmp     word [0x7DFE], 0xAA55
        jne     .err_partition_not_bootable
        mov     si, word [partition_offset]
        mov     dl, byte [boot_drive]

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

; Data
; ------------------------------------------------------------------------------
boot_drive:             db 0
partition_offset:       dw 0

msg_reading_vbr:        db "[MBR] Loading VBR... ", 0
msg_jumping_vbr:        db "[MBR] Jumping to VBR... ", 13, 10, 10, 0
msg_no_active:          db "Couldn't find active partition!", 0
msg_not_bootable:       db "Active partition not bootable!", 0
msg_success:            db "Success!", 13, 10, 0
msg_hlt:                db 13, 10, "HALT", 0

        times (0x1B4 - ($-$$)) nop      ; Pad remaining bootstrap space.
        times 10 db 0                   ; Zero DUID and reserved space.

partition_tables:
.Partition1:
        db 0x80
        db 0x00
        dw 0x0000
        db 0x07
        db 0x00
        dw 0x0000
        dd 0x00000001
        dd 333
.Partition2: times 16 db 0
.Partition3: times 16 db 0
.Partition4: times 16 db 0

        dw 0xAA55                      ; Boot signature.