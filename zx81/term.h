#ifndef TERM_H
#define TERM_H

#include <stdint.h>

#define TERM_BUFFER_SIZE 21

extern char term_buf[];

void term_pos(uint8_t x, uint8_t y);

void term_putc(int c);
void term_puts(const char *s);
void term_putul(uint32_t v);

void term_zx2ascii(const uint8_t *in);

#endif

