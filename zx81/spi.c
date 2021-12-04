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
  nop
  in a, (0xef)
  ld l, a
__endasm;
}

