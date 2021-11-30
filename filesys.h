#ifndef _FILESYS_H
#define _FILESYS_H

#include <stdint.h>

#define DRIVE_INFO_MODEL_LEN 32
#define DRIVE_INFO_FW_LEN 8
#define DRIVE_INFO_SERNO_LEN 20

#define DRIVE_TYPE_EMU  0
#define DRIVE_TYPE_MMC  1
#define DRIVE_TYPE_SDV1 2
#define DRIVE_TYPE_SDV2 3
#define DRIVE_TYPE_SDHC 4

typedef struct {
  char model[DRIVE_INFO_MODEL_LEN + 1];
  char serno[DRIVE_INFO_SERNO_LEN + 1];
  uint8_t type;
  uint32_t blk_count;
} TFS_DRIVE_INFO;

#define TFS_NAME_LEN 16

// blocksize results in 512 bytes (9 relevant bits)
#define TFS_BLOCKSIZE_WIDTH 9
#define TFS_BLOCKSIZE       (1 << TFS_BLOCKSIZE_WIDTH)

#define TFS_ERR_OK           0
#define TFS_ERR_DISK_FULL    1
#define TFS_ERR_FILE_EXIST   2
#define TFS_ERR_DIR_EXIST    3
#define TFS_ERR_NOT_EXIST    4
#define TFS_ERR_CHECKSUM     5
#define TFS_ERR_IO           6
#define TFS_ERR_NO_NAME      7
#define TFS_ERR_NAME_INVAL   8
#define TFS_ERR_UNEXP_EOF    9
#define TFS_ERR_NOT_EMPTY    10

#ifdef __GNUC__
  #define _PACKED __attribute__((packed))
#else
  #define _PACKED
#endif

typedef struct {
  uint32_t blk;
  uint32_t size;
  uint8_t type;
  char name[TFS_NAME_LEN];
} _PACKED TFS_DIR_ITEM;

#define TFS_DIR_ITEM_FREE 0
#define TFS_DIR_ITEM_DIR  1
#define TFS_DIR_ITEM_FILE 2

#define TFS_FORMAT_STATE_START        0
#define TFS_FORMAT_STATE_BITMAP_START 1
#define TFS_FORMAT_STATE_BITMAP_DONE  2
#define TFS_FORMAT_STATE_ROOTDIR      3
#define TFS_FORMAT_STATE_DONE         4

extern TFS_DRIVE_INFO drive_info;
extern uint8_t last_error;

// drive low level interface
void drive_select();
void drive_deselect();
void drive_read_block(uint32_t blkno, uint8_t *data);
void drive_write_block(uint32_t blkno, const uint8_t *data);

void tfs_init(void);

void tfs_format(void);

void tfs_read_dir(uint8_t mux);
void tfs_change_dir(const char *name);
void tfs_create_dir(const char *name);

void tfs_write_file(const char *name, const uint8_t *data, uint32_t len, uint8_t overwrite);
uint32_t tfs_read_file(const char *name, uint8_t *data, uint32_t max_len);

void tfs_delete(const char *name);

// user defined callbacks
void tfs_format_state(uint8_t state);
void tfs_format_progress(uint32_t pos, uint32_t max);

void tfs_dir_handler(uint8_t mux, const TFS_DIR_ITEM *item);

#endif
