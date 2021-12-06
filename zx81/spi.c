#include "mmc.h"

// do not warn about missing return value on assembler functions
#pragma disable_warning 59
#pragma disable_warning 85

void spi_select_drive(void) {
__asm
 out (0xf7), a
__endasm;
}

void spi_deselect_drive(void) {
__asm
 in a, (0xf7)
__endasm;
}

uint8_t spi_transfer_byte(uint8_t b) {
__asm
  ld a, 4(ix)
  out (0xef), a
  nop
  in a, (0xef)
  ld l, a
__endasm;
}

void spi_read_block(uint8_t *data, uint16_t len) {
__asm
  ld c, 6 (ix)
  ld b, 7 (ix)
  ld e, 4 (ix)
  ld d, 5 (ix)
00001$:
  ld a, b
  or a, c
  jr Z, 00002$

  ld a, #0xff
  out (0xef), a
  nop
  in a, (0xef)
  ld (de), a

  dec bc
  inc de
  jr 00001$
00002$:
__endasm;
}

void spi_write_block(const uint8_t *data, uint16_t len) {
__asm
  ld c, 6 (ix)
  ld b, 7 (ix)
  ld e, 4 (ix)
  ld d, 5 (ix)
00001$:
  ld a, b
  or a, c
  jr Z, 00002$

  ld a,(de)
  out (0xef), a

  dec bc
  inc de
  jr 00001$
00002$:
__endasm;
}

