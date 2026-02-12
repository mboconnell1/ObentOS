#ifndef KERNEL_CONSOLE_H
#define KERNEL_CONSOLE_H

#define VGA_TEXT_BUFFER     0xB8000
#define VGA_BLACK           0x00
#define VGA_BLUE            0x01
#define VGA_GREEN           0x02
#define VGA_CYAN            0x03
#define VGA_RED             0x04
#define VGA_MAGENTA         0x05
#define VGA_BROWN           0x06
#define VGA_WHITE           0x07
#define VGA_GRAY            0x08
#define VGA_LIGHT_BLUE      0x09
#define VGA_LIGHT_GREEN     0x0A
#define VGA_LIGHT_CYAN      0x0B
#define VGA_LIGHT_RED       0x0C
#define VGA_LIGHT_MAGENTA   0x0D
#define VGA_YELLOW          0x0E
#define VGA_WHITE           0x0F

void vga_clear();
void vga_write_cell(uint32_t i, char c, uint8_t fg, uint8_t bg);
void vga_write_string(uint32_t i, char* str, uint8_t fg, uint8_t bg);

#endif /* KERNEL_CONSOLE_H */
