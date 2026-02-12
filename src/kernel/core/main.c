#include <stdint.h>
#include <kernel/console.h>

void kmain(void) {
    vga_clear();
    vga_write_string(0, (char*)"ObentOS", VGA_WHITE, VGA_BLACK);
    for (;;)
        __asm__ volatile ("hlt");
}