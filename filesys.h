#ifndef _FILESYS_H
#define _FILESYS_H

#include <stdint.h>

#define DRIVE_INFO_MODEL_LEN 32
#define DRIVE_INFO_FW_LEN 8
#define DRIVE_INFO_SERNO_LEN 20

typedef struct {
  char model[DRIVE_INFO_MODEL_LEN + 1];
  char fw[DRIVE_INFO_FW_LEN + 1];
  char serno[DRIVE_INFO_SERNO_LEN + 1];
  uint32_t blk_count;
} TFS_DRIVE_INFO;

#define TFS_NAME_LEN 16

// blocksize results in 512 bytes (9 relevant bits)
#define TFS_BLOCKSIZE_WIDTH 9
#define TFS_BLOCKSIZE       (1 << TFS_BLOCKSIZE_WIDTH)

// first bitmap block must start at 0 to simlify offset calculation
#define TFS_FIRST_BITMAP_BLK 0
#define TFS_ROOT_DIR_BLK     1

#define TFS_ERR_OK          0
#define TFS_ERR_DISK_FULL   1
#define TFS_ERR_FILE_EXIST  2
#define TFS_ERR_DIR_EXIST   3
#define TFS_ERR_NOT_EXIST   4
#define TFS_ERR_CHECKSUM    5
#define TFS_ERR_IO          6
#define TFS_ERR_NO_NAME     7
#define TFS_ERR_NAME_INVAL  8

#define TFS_BLK_TYPE_FREE 0
#define TFS_BLK_TYPE_DIR  1
#define TFS_BLK_TYPE_BMAP 2
#define TFS_BLK_TYPE_FILE 3

extern TFS_DRIVE_INFO dev_info;
extern uint8_t last_error;

void dev_read_block(uint32_t blkno, void *data);
void dev_write_block(uint32_t blkno, const void *data);

void tfs_init(void);

void tfs_format(void);

void tfs_show_dir(void);
void tfs_change_dir(const char *name);
void tfs_create_dir(const char *name);

void tfs_write_file(const char *name, const void *data, uint16_t len);
void tfs_read_file(const char *name, void *data, uint16_t max_len);

#endif
