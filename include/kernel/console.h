#ifndef KERNEL_CONSOLE_H
#define KERNEL_CONSOLE_H

#define VGA_TEXT_BUFFER 0xB8000
#define VGA_GREEN       2
#define VGA_DARK_GREY   8

void fb_write_cell(unsigned int i, char c, unsigned char fg, unsigned char bg);

#endif /* KERNEL_CONSOLE_H */
