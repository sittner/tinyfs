#ifndef MMC_H
#define MMC_H

#include <stdint.h>

extern uint8_t drive_init(void);

// lowlevel spi interface
void spi_init(void);
void spi_select_drive(void);
void spi_deselect_drive(void);
uint8_t spi_transfer_byte(uint8_t b);

#endif

