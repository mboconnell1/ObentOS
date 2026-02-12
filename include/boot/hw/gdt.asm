[bits 16]

%ifndef __GDT_ASM
%define __GDT_ASM

%include "common/memory_map.inc"

gdt:
.null_descriptor:       times 8 db 0
.code_descriptor:       dw 0xFFFF
                        dw 0
                        db 0
                        db 10011010b
                        db 11001111b
                        db 0
.data_descriptor:       dw 0xffff
                        dw 0
                        db 0
                        db 10010010b
                        db 11001111b
                        db 0
.length equ $-gdt

gdt_meta:
.size:                  dw  gdt.length-1
.loc:                   dd  gdt

gdt_meta_global:
.size:                  dw  gdt.length-1
.loc:                   dd  (GDT_SEG << 4 | GDT_OFF)

%macro EnterProtectedMode32 2
        push    eax

        lgdt    [%1]

        mov     eax, cr0
        or      eax, 1
        mov     cr0, eax

        o32     jmp     far [%%.pmode32_ptr]
%%.pmode32_ptr:
                        dd %%.pmode32_stub
                        dw 0x08

[bits 32]
%%.pmode32_stub:
        cli

        mov     ax, 0x10
        mov     ds, ax
        mov     es, ax
        mov     gs, ax
        mov     fs, ax
        mov     ss, ax

        pop     eax

        jmp     %2
[bits 16]
%endmacro

copy_gdt_to_global:
        push    ds
        push    es
        mov     ax, cs
        mov     ds, ax
        mov     si, gdt
        mov     ax, GDT_SEG
        mov     es, ax
        mov     di, GDT_OFF
        mov     cx, gdt.length
        rep     movsb
        pop     es
        pop     ds
        ret

%endif
