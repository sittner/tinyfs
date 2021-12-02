#include "term.h"

#include <stdlib.h>

#define D_FILE_ADR 16396
#define LAST_K_ADR 16421
#define CDFLAG_ADR 16443

static volatile uint8_t * __at D_FILE_ADR D_FILE;

// table mapping ascii (7-bit) to ZX81 char set
// starts from space (32)
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

void term_clrscrn() {
__asm
        ld hl,(D_FILE_ADR)
        dec hl
        ld a,#24
00001$: inc hl
        inc hl
        ld d,h
        ld e,l
        inc de
        ld bc,#31
        ld (hl),#0
        ldir
        dec a
        jr nz,00001$

__endasm;
}

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
  term_putsn(s, 32);
}

void term_putsn(const char *s, uint8_t max_len) {
  for (; *s != 0 && max_len > 0; s++, max_len--) {
    term_putc(*s);
  }
}

void term_putul(uint32_t v) {
  __ultoa(v, term_buf, 10);
  term_puts(term_buf);
}

uint16_t term_get_key(void) {
__asm
        push ix

        ld a,(CDFLAG_ADR)   ; save CDFLAG
        push af

        call _ROM_SLOW       ; force slow mode

00001$: ld hl,(LAST_K_ADR)  ; wait for key
        ld a,h
        and a,h
	cp #0xff
        jp z,00001$

        push hl              ; remember key code

00002$: ld hl,(LAST_K_ADR)  ; wait for key release
        ld a,h
        and a,h
	cp #0xff
        jp nz,00002$

        call _ROM_FAST       ; force fast mode

        pop hl               ; recall key code

        pop af               ; restore CDFLAG
        ld (CDFLAG_ADR),a

        pop ix

        ret;
__endasm;
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

