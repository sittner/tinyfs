#include "mmc.h"

// do not warn about missing return value on assembler functions
#pragma disable_warning 59
#pragma disable_warning 85

void spi_select_drive(void) {
__asm
  in a, (0xef)
__endasm;
}

void spi_deselect_drive(void) {
__asm
  in a, (0xf7)
__endasm;
}

uint8_t spi_transfer_byte(uint8_t b) {
// __sdcccall(1):
// arg 'b' (8 bit) -> reg 'a'
// return value (8 bit) -> reg 'a'
__asm
  out (0xef), a
  nop
  in a, (0xef)
__endasm;
}

void spi_read_block(uint8_t *data, uint16_t len) {
// __sdcccall(1):
// arg '*data' (16 bit) -> reg 'hl'
// arg 'len' (16 bit) -> reg 'de'
__asm
00001$:
  ld a, d
  or a, e
  jr Z, 00002$

  ld a, #0xff
  out (0xef), a
  nop
  in a, (0xef)
  ld (hl), a

  dec de
  inc hl
  jr 00001$
00002$:
__endasm;
}

void spi_write_block(const uint8_t *data, uint16_t len) {
// arg '*data' (16 bit) -> reg 'hl'
// arg 'len' (16 bit) -> reg 'de'
__asm
00001$:
  ld a, d
  or a, e
  jr Z, 00002$

  ld a,(hl)
  out (0xef), a

  dec de
  inc hl
  jr 00001$
00002$:
__endasm;
}

void spi_dummy_transfer(uint16_t len) {
// __sdcccall(1):
// arg 'len' (16 bit) -> reg 'hl'
__asm
00001$:
  ld a, h
  or a, l
  jr Z, 00002$

  ld a, #0xff
  out (0xef), a

  dec hl
  jr 00001$
00002$:
__endasm;
}

