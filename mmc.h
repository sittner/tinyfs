#ifndef MMC_H
#define MMC_H

#include <stdint.h>

// lowlevel spi interface
void spi_select_drive(void);
void spi_deselect_drive(void);
void spi_read_block(uint8_t *data, uint16_t len);
void spi_write_block(const uint8_t *data, uint16_t len);
void spi_dummy_transfer(uint16_t len);

#endif

