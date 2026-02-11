BITS 32
ORG  0x00100000

_start:
    mov     al, '1'
    mov     ah, 0x0f
    mov     [0xB8000], ax
.hang:
    cli
    hlt
    jmp .hang