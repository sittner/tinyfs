#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#define TFS_ENABLE_FORMAT
#undef TFS_EXTENDED_API
#undef TFS_READ_DIR_USERDATA

#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif

