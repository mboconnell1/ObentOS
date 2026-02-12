[bits 16]
%include "common/defs.inc"
[org STAGE2_MEM]

        jmp _start

; Includes
; ------------------------------------------------------------------------------
%include "bios/e820.asm"
%include "fs/fat12.asm"
%include "bios/print_string.asm"
%include "bios/read_disk.asm"
%include "fs/volume.asm"
%include "hw/gdt.asm"

%define VGA_TEXT_MEM       0xB8000

; Code
; ------------------------------------------------------------------------------
_start:

        cli
        
        mov     ax, STAGE2_STACK_TOP_SEG
        mov     ss, ax
        mov     sp, STAGE2_STACK_TOP_OFF
        mov     bp, sp

        mov     ax, cs
        mov     ds, ax
        mov     es, ax
        
        cld
        sti
        
        mov     ax, BOOT_INFO_SEG
        mov     fs, ax
        mov     si, BOOT_INFO_OFF

        mov     dl, [fs:si + boot_info_t.BootDrive]
        mov     [g_BootDrive], dl

        ; Get memory information.
        PRINT_STRING MSG_E820
        call    DetectMemoryE820
        jc      halt
        PRINT_STRING MSG_SUCCESS

        ; Initialise volume layout.
        PRINT_STRING MSG_INIT_VOLUME
        call    volume_init_layout
        jc      halt
        PRINT_STRING MSG_SUCCESS

        ; Locate KERNEL.BIN.
        PRINT_STRING MSG_FIND_KERNEL
        mov     si, KERNEL_FILENAME
        call    fat12_find_root_file
        jc      halt
        PRINT_STRING MSG_SUCCESS

        mov     [kernel_first_cluster], bx
        mov     [kernel_file_size], eax

        ; Load the kernel into a buffer.
        PRINT_STRING MSG_KERNEL_BUF_LDNG
        mov     ax, STAGE2_KERNEL_BUF_SEG
        mov     es, ax
        mov     di, STAGE2_KERNEL_BUF_OFF

        mov     ax, [kernel_first_cluster]
        mov     esi, [kernel_file_size]

        call    fat12_load_file_chain
        jc      halt
        PRINT_STRING MSG_SUCCESS

        ; Copy GDT to global location.
        PRINT_STRING MSG_COPYING_GDT
        call copy_gdt_to_global
        PRINT_STRING MSG_SUCCESS

        ; Switch to protected mode.
        PRINT_STRING MSG_SWITCHING_PM
        EnterProtectedMode32 gdt_meta_global, pmode_entry

[bits 32]
pmode_entry:
        mov     esp, STAGE2_STACK_TOP_MEM

        mov     esi, STAGE2_KERNEL_BUF_MEM
        mov     edi, KERNEL_MEM
        mov     ecx, [kernel_file_size]
        test    ecx, ecx
        jz      .copy_done
        cld
        rep     movsb
.copy_done:
        jmp     KERNEL_MEM

[bits 16]

halt:
        PRINT_STRING MSG_HLT
        jmp     $

; Data
; ------------------------------------------------------------------------------
KERNEL_FILENAME:        db 'KERNEL  BIN'      ; 11 bytes

kernel_first_cluster:   dw 0
kernel_file_size:       dd 0

MSG_E820:               db "[STAGE 2] Detecting available memory... ", 0
MSG_INIT_VOLUME:        db "[STAGE 2] Initialising volume layout... ", 0
MSG_FIND_KERNEL:        db "[STAGE 2] Searching for KERNEL.BIN... ", 0
MSG_KERNEL_BUF_LDNG:    db "[STAGE 2] Loading kernel into buffer... ", 0
MSG_COPYING_GDT:        db "[STAGE 2] Copying GDT to global location... ", 0
MSG_SWITCHING_PM:       db "[STAGE 2] Switching to protected mode...", 0

MSG_SUCCESS:            db "Success!", 13, 10, 0
MSG_HLT:                db 13, 10, "HALT", 0
