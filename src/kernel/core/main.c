#include <stdint.h>
#include <kernel/vga.h>

void kmain(void) {
    vga_clear();
    vga_write_string_at_pos(0, 0, (char*)"ObentOS", VGA_WHITE, VGA_BLACK);
    for (;;)
        __asm__ volatile ("hlt");
}