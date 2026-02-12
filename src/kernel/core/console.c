#include <stdint.h>
#include <kernel/console.h>

volatile uint16_t *fb = (volatile uint16_t *)VGA_TEXT_BUFFER;

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg)
{
    fb[i] = (uint16_t)(c | (((bg & 0x0F) << 4 | (fg & 0x0F)) << 8));
}