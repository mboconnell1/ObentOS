BITS 32
ORG  0x00100000

_start:

.hang:
    cli
    hlt
    jmp .hang