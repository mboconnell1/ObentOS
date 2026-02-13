#include <stdint.h>
#include <kernel/vga.h>

volatile uint16_t *vga_text_buf = (volatile uint16_t *)VGA_TEXT_BUFFER;

void vga_clear()
{
    for (int i = 0; i < VGA_CELL_COUNT; i++)
    {
        vga_write_cell_at_idx(i, ' ', VGA_WHITE, VGA_BLACK);
    }
}

uint8_t vga_pack_attr(uint8_t fg, uint8_t bg)
{
    uint8_t attr = (bg << 4) | (fg & 0x0F);
    return attr;
}

void vga_write_cell_at_idx(uint32_t i, char c, uint8_t fg, uint8_t bg)
{
    vga_text_buf[i] = (uint16_t)(c | vga_pack_attr(fg, bg) << 8);
}
void vga_write_cell_at_pos(uint32_t row, uint32_t col, char c, uint8_t fg, uint8_t bg)
{
    vga_text_buf[row * VGA_WIDTH + col] = (uint16_t)(c | vga_pack_attr(fg, bg) << 8);
}

void vga_write_string_at_idx(uint32_t i, char* str, uint8_t fg, uint8_t bg)
{
    for (const char *p = str; *p; ++p)
    {
        vga_write_cell_at_idx(i++, *p, fg, bg);
    }
}
void vga_write_string_at_pos(uint32_t row, uint32_t col, char* str, uint8_t fg, uint8_t bg)
{
    uint32_t i = row * VGA_WIDTH + col;
    for (const char *p = str; *p; ++p)
    {
        vga_write_cell_at_idx(i++, *p, fg, bg);
    }
}