#include <stdint.h>
#include <kernel/console.h>

void kmain(void) {
    fb_write_cell(0, 'A', VGA_GREEN, VGA_DARK_GREY);
    for (;;)
        __asm__ volatile ("hlt");
}