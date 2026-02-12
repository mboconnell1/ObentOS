#include <stdint.h>
#include <kernel/console.h>

volatile uint16_t *vga_text_buf = (volatile uint16_t *)VGA_TEXT_BUFFER;

void vga_clear()
{
    for (int i = 0; i < 2000; i++)
    {
        vga_write_cell(i, ' ', VGA_WHITE, VGA_BLACK);
    }
}

uint8_t vga_attr(uint8_t fg, uint8_t bg)
{
    uint8_t attr = (bg << 4) | (fg & 0x0F);
    return attr;
}

void vga_write_cell(uint32_t i, char c, uint8_t fg, uint8_t bg)
{
    vga_text_buf[i] = (uint16_t)(c | vga_attr(fg, bg) << 8);
}

void vga_write_string(uint32_t i, char* str, uint8_t fg, uint8_t bg)
{
    for (const char *p = str; *p; ++p)
    {
        vga_write_cell(i++, *p, fg, bg);
    }
}