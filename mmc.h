#ifndef MMC_H
#define MMC_H

#include <stdint.h>

extern uint8_t drive_init(void);

// lowlevel spi interface
void spi_select_drive(void);
void spi_deselect_drive(void);
uint8_t spi_transfer_byte(uint8_t b);
void spi_read_block(uint8_t *data, uint16_t len);
void spi_write_block(const uint8_t *data, uint16_t len);
void spi_dummy_transfer(uint16_t len);

#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)

#endif

