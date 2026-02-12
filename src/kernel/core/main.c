#include <stdint.h>

void kmain(void) {
    volatile uint16_t *vga = (uint16_t *)0xB8000;
    vga[0] = (uint16_t)('2' | (0x0F << 8));
    for (;;)
        __asm__ volatile ("hlt");
}