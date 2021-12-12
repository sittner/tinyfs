#ifndef _FILESYS_PRIV_H
#define _FILESYS_PRIV_H

#include "filesys.h"

// first bitmap block must start at 0 to simlify offset calculation
#define TFS_FIRST_BITMAP_BLK 0
#define TFS_ROOT_DIR_BLK     1

typedef struct {
  uint32_t prev;
  uint32_t next;
  uint8_t data[];
} _PACKED TFS_DATA_BLK;

#define TFS_DATA_LEN (TFS_BLOCKSIZE - sizeof(TFS_DATA_BLK))

typedef struct {
  uint32_t prev;
  uint32_t next;
  uint32_t parent;
  TFS_DIR_ITEM items[];
} _PACKED TFS_DIR_BLK;

#define TFS_DIR_BLK_ITEMS ((TFS_BLOCKSIZE - sizeof(TFS_DIR_BLK)) / sizeof(TFS_DIR_ITEM))

typedef union {
  uint8_t raw[TFS_BLOCKSIZE];
  TFS_DIR_BLK dir;
  TFS_DATA_BLK data;
} TFS_BLK_BUFFER;

#endif
