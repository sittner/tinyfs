#include "term.h"

#include <stdlib.h>

static volatile uint8_t * __at 16396 D_FILE;
static volatile uint16_t  __at 16421 LAST_K;

static const uint8_t ascii2zx[96] = {
  00, 00, 11, 12, 13, 00, 00, 11,
  16, 17, 23, 21, 26, 22, 27, 24,
  28, 29, 30, 31, 32, 33, 34, 35,
  36, 37, 14, 25, 19, 20, 18, 15,
  23, 38, 39, 40, 41, 42, 43, 44,
  45, 46, 47, 48, 49, 50, 51, 52,
  53, 54, 55, 56, 57, 58, 59, 60,
  61, 62, 63, 16, 24, 17, 11, 22,
  11, 38, 39, 40, 41, 42, 43, 44,
  45, 46, 47, 48, 49, 50, 51, 52,
  53, 54, 55, 56, 57, 58, 59, 60,
  61, 62, 63, 16, 24, 17, 11, 00
};

static const char zx2ascii[128 + 1] =
  "           \"@$:?" //   0 -  15
  "()><=+-*/;,.0123"  //  16 -  31
  "456789abcdefghij"  //  32 -  47
  "klmnopqrstuvwxyz"  //  48 -  63
  "                "  //  64 -  79
  "                "  //  80 -  95
  "                "  //  96 - 111
  "                "; // 112 - 127

static uint8_t *pos;

char term_buf[TERM_BUFFER_SIZE];

void term_pos(uint8_t x, uint8_t y) {
  pos = D_FILE + 1 + (y * 33) + x;
}

void term_putc(int c) {
  c = (c & 0x7f) - ' ';
  if (c < 0) {
    c = 0;
  }
  *(pos++) = ascii2zx[c];
}

void term_puts(const char *s) {
  for (; *s != 0; s++) {
    term_putc(*s);
  }
}

void term_putul(uint32_t v) {
  __ultoa(v, term_buf, 10);
  term_puts(term_buf);
}

void term_zx2ascii(const uint8_t *in) {
  uint8_t i;
  char *out;

  for (i = 0, out = term_buf; i < (TERM_BUFFER_SIZE - 1); i++, in++) {
    *(out++) = zx2ascii[*in & 0x7f];
    if (*in & 0x80) {
      break;
    }
  }

  *out = 0;
}

