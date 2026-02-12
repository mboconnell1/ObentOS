[bits 32]
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