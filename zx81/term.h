#ifndef TERM_H
#define TERM_H

#include <stdint.h>

#define TERM_BUFFER_SIZE 48

#define TERM_KEY_Z      (~(0x0001 << 0) & ~(0x0100 << 2))
#define TERM_KEY_X      (~(0x0001 << 0) & ~(0x0100 << 3))
#define TERM_KEY_C      (~(0x0001 << 0) & ~(0x0100 << 4))
#define TERM_KEY_V      (~(0x0001 << 0) & ~(0x0100 << 5))
#define TERM_KEY_A      (~(0x0001 << 1) & ~(0x0100 << 1))
#define TERM_KEY_S      (~(0x0001 << 1) & ~(0x0100 << 2))
#define TERM_KEY_D      (~(0x0001 << 1) & ~(0x0100 << 3))
#define TERM_KEY_F      (~(0x0001 << 1) & ~(0x0100 << 4))
#define TERM_KEY_G      (~(0x0001 << 1) & ~(0x0100 << 5))
#define TERM_KEY_Q      (~(0x0001 << 2) & ~(0x0100 << 1))
#define TERM_KEY_W      (~(0x0001 << 2) & ~(0x0100 << 2))
#define TERM_KEY_E      (~(0x0001 << 2) & ~(0x0100 << 3))
#define TERM_KEY_R      (~(0x0001 << 2) & ~(0x0100 << 4))
#define TERM_KEY_T      (~(0x0001 << 2) & ~(0x0100 << 5))
#define TERM_KEY_1      (~(0x0001 << 3) & ~(0x0100 << 1))
#define TERM_KEY_2      (~(0x0001 << 3) & ~(0x0100 << 2))
#define TERM_KEY_3      (~(0x0001 << 3) & ~(0x0100 << 3))
#define TERM_KEY_4      (~(0x0001 << 3) & ~(0x0100 << 4))
#define TERM_KEY_5      (~(0x0001 << 3) & ~(0x0100 << 5))
#define TERM_KEY_0      (~(0x0001 << 4) & ~(0x0100 << 1))
#define TERM_KEY_9      (~(0x0001 << 4) & ~(0x0100 << 2))
#define TERM_KEY_8      (~(0x0001 << 4) & ~(0x0100 << 3))
#define TERM_KEY_7      (~(0x0001 << 4) & ~(0x0100 << 4))
#define TERM_KEY_6      (~(0x0001 << 4) & ~(0x0100 << 5))
#define TERM_KEY_P      (~(0x0001 << 5) & ~(0x0100 << 1))
#define TERM_KEY_O      (~(0x0001 << 5) & ~(0x0100 << 2))
#define TERM_KEY_I      (~(0x0001 << 5) & ~(0x0100 << 3))
#define TERM_KEY_U      (~(0x0001 << 5) & ~(0x0100 << 4))
#define TERM_KEY_Y      (~(0x0001 << 5) & ~(0x0100 << 5))
#define TERM_KEY_ENT    (~(0x0001 << 6) & ~(0x0100 << 1))
#define TERM_KEY_L      (~(0x0001 << 6) & ~(0x0100 << 2))
#define TERM_KEY_K      (~(0x0001 << 6) & ~(0x0100 << 3))
#define TERM_KEY_J      (~(0x0001 << 6) & ~(0x0100 << 4))
#define TERM_KEY_H      (~(0x0001 << 6) & ~(0x0100 << 5))
#define TERM_KEY_SPC    (~(0x0001 << 7) & ~(0x0100 << 1))
#define TERM_KEY_DOT    (~(0x0001 << 7) & ~(0x0100 << 2))
#define TERM_KEY_M      (~(0x0001 << 7) & ~(0x0100 << 3))
#define TERM_KEY_N      (~(0x0001 << 7) & ~(0x0100 << 4))
#define TERM_KEY_B      (~(0x0001 << 7) & ~(0x0100 << 5))

extern char term_buf[];

void term_clrscrn(void);

void term_putc(char c);
void term_puts(const char *s);
void term_putsn(const char *s, uint8_t max_len);
void term_putul(uint32_t v);
void term_putul_aligned(uint32_t v, uint8_t size);

uint16_t term_get_key(void);

void term_zx2ascii(const uint8_t *in);

#endif

