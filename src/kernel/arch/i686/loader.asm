[bits 32]
%include "../kernel/header.inc"

section .kernel_header
global kernel_header
kernel_header:
    dd KERNEL_HEADER_MAGIC
    dd _start

section .text
global _start
extern kmain
extern kernel_stack_top

_start:
    mov     esp, kernel_stack_top
    call    kmain
.hang:
    cli
    hlt
    jmp     .hang
