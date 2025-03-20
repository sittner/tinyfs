#include "mmc.h"
#include "filesys.h"

#include <string.h>

// commands available in SPI mode

// CMD0: response R1
#define CMD_GO_IDLE_STATE 0x00

// CMD1: response R1
#define CMD_SEND_OP_COND 0x01

// CMD8: response R7
#define CMD_SEND_IF_COND 0x08

// CMD9: response R1
#define CMD_SEND_CSD 0x09

// CMD10: response R1
#define CMD_SEND_CID 0x0a

// CMD12: response R1
#define CMD_STOP_TRANSMISSION 0x0c

// CMD13: response R2
#define CMD_SEND_STATUS 0x0d

// CMD16: arg0[31:0]: block length, response R1
#define CMD_SET_BLOCKLEN 0x10

// CMD17: arg0[31:0]: data address, response R1
#define CMD_READ_SINGLE_BLOCK 0x11

// CMD18: arg0[31:0]: data address, response R1
#define CMD_READ_MULTIPLE_BLOCK 0x12

// CMD24: arg0[31:0]: data address, response R1
#define CMD_WRITE_SINGLE_BLOCK 0x18

// CMD25: arg0[31:0]: data address, response R1
#define CMD_WRITE_MULTIPLE_BLOCK 0x19

// CMD27: response R1
#define CMD_PROGRAM_CSD 0x1b

// CMD28: arg0[31:0]: data address, response R1b
#define CMD_SET_WRITE_PROT 0x1c

// CMD29: arg0[31:0]: data address, response R1b
#define CMD_CLR_WRITE_PROT 0x1d

// CMD30: arg0[31:0]: write protect data address, response R1
#define CMD_SEND_WRITE_PROT 0x1e

// CMD32: arg0[31:0]: data address, response R1
#define CMD_TAG_SECTOR_START 0x20

// CMD33: arg0[31:0]: data address, response R1
#define CMD_TAG_SECTOR_END 0x21

// CMD34: arg0[31:0]: data address, response R1
#define CMD_UNTAG_SECTOR 0x22

// CMD35: arg0[31:0]: data address, response R1
#define CMD_TAG_ERASE_GROUP_START 0x23

// CMD36: arg0[31:0]: data address, response R1
#define CMD_TAG_ERASE_GROUP_END 0x24

// CMD37: arg0[31:0]: data address, response R1
#define CMD_UNTAG_ERASE_GROUP 0x25

// CMD38: arg0[31:0]: stuff bits, response R1b
#define CMD_ERASE 0x26

// ACMD41: arg0[31:0]: OCR contents, response R1
#define CMD_SD_SEND_OP_COND 0x29

// CMD42: arg0[31:0]: stuff bits, response R1b
#define CMD_LOCK_UNLOCK 0x2a

// CMD55: arg0[31:0]: stuff bits, response R1
#define CMD_APP 0x37

// CMD58: arg0[31:0]: stuff bits, response R3
#define CMD_READ_OCR 0x3a

// CMD59: arg0[31:1]: stuff bits, arg0[0:0]: crc option, response R1
#define CMD_CRC_ON_OFF 0x3b

// command responses
// R1: size 1 byte
#define STATE_IDLE_STATE    (1 << 0)
#define STATE_ERASE_RESET   (1 << 1)
#define STATE_ILL_COMMAND   (1 << 2)
#define STATE_COM_CRC_ERR   (1 << 3)
#define STATE_ERASE_SEQ_ERR (1 << 4)
#define STATE_ADDR_ERR      (1 << 5)
#define STATE_PARAM_ERR     (1 << 6)

#define TIMEOUT 0x7fff

// private helper functions
static char hex_char(uint8_t val);
static uint8_t wait_byte(uint8_t val);
static uint8_t send_command(uint8_t command, uint32_t arg);
static uint8_t get_info(void);

static uint8_t tmp_buf[18];

uint8_t drive_init(void) {
  uint8_t resp;
  uint16_t i;

  // initialization procedure
  drive_info.type = DRIVE_TYPE_MMC;
    
  // card needs 74 cycles minimum to start up
  spi_dummy_transfer(10);

  // address card
  drive_select();

  // reset card
  for (i = 0; send_command(CMD_GO_IDLE_STATE, 0) != STATE_IDLE_STATE; i++) {
    // handle timeout
    if (i == 0x1ff) {
      goto fail;
    }
  }

  // check for version of SD card specification
  resp = send_command(CMD_SEND_IF_COND,
     0x100 // 2.7V - 3.6V
    | 0xaa // test pattern
  );
  if ((resp & STATE_ILL_COMMAND) == 0) {
    spi_read_block(tmp_buf, 4);

    if ((tmp_buf[2] & 0x01) == 0) {
      // card operation voltage range doesn't match
      goto fail;
    }

    if (tmp_buf[3] != 0xaa) {
      // wrong test pattern
      goto fail;
    }

    // card conforms to SD 2 card specification
    drive_info.type = DRIVE_TYPE_SDV2;
  } else {
    // determine SD/MMC card type
    send_command(CMD_APP, 0);
    resp = send_command(CMD_SD_SEND_OP_COND, 0);
    if ((resp & STATE_ILL_COMMAND) == 0) {
      // card conforms to SD 1 card specification
      drive_info.type = DRIVE_TYPE_SDV1;
    }
  }

  // wait for card to get ready
  for (i = 0;; i++) {
    if (drive_info.type == DRIVE_TYPE_MMC) {
      resp = send_command(CMD_SEND_OP_COND, 0);
    } else {
      send_command(CMD_APP, 0);
      if (drive_info.type == DRIVE_TYPE_SDV2) {
        resp = send_command(CMD_SD_SEND_OP_COND, 0x40000000);
      } else {
        resp = send_command(CMD_SD_SEND_OP_COND, 0);
      }
    }

    if ((resp & STATE_IDLE_STATE) == 0) {
      break;
    }

    // handle timeout
    if (i == TIMEOUT) {
      goto fail;
    }
  }

  if (drive_info.type == DRIVE_TYPE_SDV2) {
    if (send_command(CMD_READ_OCR, 0)) {
      goto fail;
    }

    spi_read_block(tmp_buf, 4);

    if (tmp_buf[0] & 0x40) {
      drive_info.type = DRIVE_TYPE_SDHC;
    }
  }

  // set block size to 512 bytes
  if (send_command(CMD_SET_BLOCKLEN, TFS_BLOCKSIZE)) {
    goto fail;
  }

  if (!get_info()) {
    goto fail;
  }

  // deaddress card
  drive_deselect();

  return 1;

fail:
  drive_deselect();
  return 0;
}

void drive_select(void) {
  // Create 8 clock pulse before activating the card
  spi_dummy_transfer(1);

  spi_select_drive();
}

void drive_deselect(void) {
  spi_deselect_drive();

  // Create 80 clock pulse after releasing the card
  spi_dummy_transfer(10);
}

static char hex_char(uint8_t val) {
  val &= 0x0f;
  if (val >= 10) {
    return 'A' + val - 10;
  }
  return '0' + val;
}

static uint8_t wait_byte(uint8_t val) {
  uint16_t timeout = TIMEOUT;
  while (spi_rec_byte() != val) {
    if (timeout == 0) {
      return 0;
    }
    timeout--;
  }
  return 1;
}

static uint8_t send_command(uint8_t command, uint32_t arg) {
  uint8_t resp;
  uint8_t i;

  // wait some clock cycles
  spi_rec_byte();

  // send command via SPI
  spi_send_byte(0x40 | command);
  spi_send_byte(arg >> 24);
  spi_send_byte(arg >> 16);
  spi_send_byte(arg >> 8);
  spi_send_byte(arg >> 0);

  switch(command) {
    case CMD_GO_IDLE_STATE:
      spi_send_byte(0x95);
      break;
    case CMD_SEND_IF_COND:
      spi_send_byte(0x87);
      break;
    default:
      spi_send_byte(0xff);
      break;
  }
    
  // receive response
  for (resp = 0xff, i = 0; resp == 0xff && i < 10; i++) {
    resp = spi_rec_byte();
  }

  return resp;
}

void drive_read_block(uint32_t blkno, uint8_t *data) {
  // use byte offset if not SDHC
  if (drive_info.type != DRIVE_TYPE_SDHC) {
    blkno <<= TFS_BLOCKSIZE_WIDTH;
  }

  // send single block request
  if (send_command(CMD_READ_SINGLE_BLOCK, blkno)) {
    last_error = TFS_ERR_IO;
    return;
  }

  // wait for data block (start byte 0xfe)
  if (!wait_byte(0xfe)) {
    last_error = TFS_ERR_IO;
    return;
  }

  // read byte block
  spi_read_block(data, TFS_BLOCKSIZE);

  // read crc16
  spi_read_block(tmp_buf, 2);
}

void drive_write_block(uint32_t blkno, const uint8_t *data) {
  // use byte offset if not SDHC
  if (drive_info.type != DRIVE_TYPE_SDHC) {
    blkno <<= TFS_BLOCKSIZE_WIDTH;
  }

  // send single block request
  if (send_command(CMD_WRITE_SINGLE_BLOCK, blkno)) {
    last_error = TFS_ERR_IO;
    return;
  }

  // 8 dummy cycles if the command is a write command
  spi_rec_byte();

  // send start byte
  spi_send_byte(0xfe);

  // write byte block
  spi_write_block(data, TFS_BLOCKSIZE);

  // write dummy crc16
  spi_send_byte(0xff);
  spi_send_byte(0xff);

  // wait while card is busy
  if (!wait_byte(0xff)) {
    last_error = TFS_ERR_IO;
    return;
  }
}

static uint8_t get_info(void) {
  uint8_t manuf;
  uint8_t b;
  uint8_t csd_read_bl_len;
  uint8_t csd_c_size_mult;
  uint32_t csd_c_size;
  uint8_t csd_structure;
  uint8_t *p;
  char *model = drive_info.model;
  char *serno = drive_info.serno;

  // read cid register
  if(send_command(CMD_SEND_CID, 0)) {
    return 0;
  }

  if (!wait_byte(0xfe)) {
    return 0;
  }

  spi_read_block(tmp_buf, 18);
  p = tmp_buf;

  manuf = *(p++);
  p += 2;
  for (b = 0; b < 5; b++) {
    *(model++) = *(p++);
  }
    *(model++) = ' ';
    *(model++) = 'M';
    *(model++) = 'F';
    *(model++) = hex_char(manuf >> 4);
    *(model++) = hex_char(manuf);
  *(model++) = ' ';
    *(model++) = 'R';
    *(model++) = hex_char(*p >> 4);
    *(model++) = hex_char(*(p++));
  *(serno++) = hex_char(*p >> 4);
    *(serno++) = hex_char(*(p++));
  *(serno++) = hex_char(*p >> 4);
    *(serno++) = hex_char(*(p++));
  *(serno++) = hex_char(*p >> 4);
    *(serno++) = hex_char(*(p++));
  *(serno++) = hex_char(*p >> 4);
    *(serno++) = hex_char(*(p++));
    *(serno++) = 0;
  *(model++) = ' ';
    *(model++) = 'M';
    *(model++) = 'D';
    *(model++) = hex_char(*(p++));
  *(model++) = hex_char(*p >> 4);
    *(model++) = '/';
    *(model++) = hex_char(*(p++));
    *(model++) = 0;

  // read csd register
  if(send_command(CMD_SEND_CSD, 0)) {
    return 0;
  }

  if (!wait_byte(0xfe)) {
    return 0;
  }

  spi_read_block(tmp_buf, 18);
  p = tmp_buf;

  csd_structure = *(p++) >> 6;
  p += 4;

  if (csd_structure == 0x01) {
    p += 2;
    csd_c_size  = (uint32_t) (*(p++) & 0x3f) << 16;
    csd_c_size |= (uint32_t) *(p++) << 8;
    csd_c_size |= *(p++);
      csd_c_size++;
    p ++;
    drive_info.blk_count = csd_c_size * 1024;
  } else {
    csd_read_bl_len = *(p++) & 0x0f;
    csd_c_size  = (uint32_t) (*(p++) & 0x03) << 10;
    csd_c_size |= (uint32_t) *(p++) << 2;
    csd_c_size |= *(p++) >> 6;
      csd_c_size++;
    csd_c_size_mult  = (*(p++) & 0x03) << 1;
    csd_c_size_mult |= *(p++) >> 7;
    csd_c_size <<= csd_c_size_mult + csd_read_bl_len + 2;
    drive_info.blk_count = csd_c_size >> TFS_BLOCKSIZE_WIDTH;
  }

  return 1;
}

