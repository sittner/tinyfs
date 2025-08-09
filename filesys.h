#ifndef _FILESYS_H
#define _FILESYS_H

#include <stdint.h>

#include "filesys_conf.h"

#ifdef __GNUC__
  #define _PACKED __attribute__((packed))
#else
  #define _PACKED
#endif

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
#define TFS_ERR_NO_DEV       1
#define TFS_ERR_IO           2
#define TFS_ERR_DISK_FULL    3
#define TFS_ERR_FILE_EXIST   4
#define TFS_ERR_NOT_EXIST    5
#define TFS_ERR_NOT_EMPTY    6
#define TFS_ERR_NO_NAME      7
#define TFS_ERR_NAME_INVAL   8
#define TFS_ERR_UNEXP_EOF    9
#ifdef TFS_EXTENDED_API
#define TFS_ERR_NO_FREE_FD  100
#define TFS_ERR_INVAL_FD    101
#define TFS_FILE_BUSY       102
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

extern TFS_DRIVE_INFO tfs_drive_info;
extern uint8_t tfs_last_error;

// drive low level interface
void drive_init(void);
void drive_select(void);
void drive_deselect(void);
void drive_read_block(uint32_t blkno, uint8_t *data);
void drive_write_block(uint32_t blkno, const uint8_t *data);

void tfs_init(void);

#ifdef TFS_ENABLE_FORMAT
void tfs_format(void);

#ifdef TFS_FORMAT_STATE_CALLBACK
#define TFS_FORMAT_STATE_START        0
#define TFS_FORMAT_STATE_BITMAP_START 1
#define TFS_FORMAT_STATE_BITMAP_DONE  2
#define TFS_FORMAT_STATE_ROOTDIR      3
#define TFS_FORMAT_STATE_DONE         4

// user defined callbacks
void tfs_format_state(uint8_t state);
void tfs_format_progress(uint32_t pos, uint32_t max);
#endif

#endif

uint32_t tfs_get_used(void);

#ifdef TFS_READ_DIR_USERDATA
uint8_t tfs_read_dir(TFS_READ_DIR_USERDATA data);
uint8_t tfs_dir_handler(TFS_READ_DIR_USERDATA data, const TFS_DIR_ITEM *item);
#else
uint8_t tfs_read_dir(void);
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item);
#endif

void tfs_change_dir_root(void);
void tfs_change_dir_parent(void);
void tfs_change_dir(const char *name);
void tfs_create_dir(const char *name);

void tfs_write_file(const char *name, const uint8_t *data, uint32_t len, uint8_t overwrite);
uint32_t tfs_read_file(const char *name, uint8_t *data, uint32_t max_len);

#ifdef TFS_EXTENDED_API
void tfs_delete(const char *name, uint8_t type);
#else
void tfs_delete(const char *name);
#endif

void tfs_rename(const char *from, const char *to);

#ifdef TFS_EXTENDED_API
TFS_DIR_ITEM *tfs_stat(const char *name);
void tfs_touch(const char *name);
int8_t tfs_open(const char *name);
void tfs_close(int8_t fd);
void tfs_trunc(int8_t fd, uint32_t size);
uint32_t tfs_write(int8_t fd, const uint8_t *data, uint32_t len, uint32_t offset);
uint32_t tfs_read(int8_t fd, uint8_t *data, uint32_t len, uint32_t offset);
#endif

#endif
