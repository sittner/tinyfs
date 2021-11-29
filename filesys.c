#include "filesys.h"

#include <string.h>

// first bitmap block must start at 0 to simlify offset calculation
#define TFS_FIRST_BITMAP_BLK 0
#define TFS_ROOT_DIR_BLK     1

typedef struct {
  uint32_t next;
  uint8_t data[];
} __attribute__((packed)) TFS_DATA_BLK;

#define TFS_DATA_LEN (TFS_BLOCKSIZE - sizeof(TFS_DATA_BLK))

typedef struct {
  uint32_t prev;
  uint32_t next;
  uint32_t parent;
  TFS_DIR_ITEM items[];
} __attribute__((packed)) TFS_DIR_BLK;

#define TFS_DIR_BLK_ITEMS ((TFS_BLOCKSIZE - sizeof(TFS_DIR_BLK)) / sizeof(TFS_DIR_ITEM))

typedef union {
  uint8_t raw[TFS_BLOCKSIZE];
  TFS_DIR_BLK dir;
  TFS_DATA_BLK data;
} TFS_BLK_BUFFER;

TFS_DRIVE_INFO dev_info;
uint8_t last_error;

static const char *invalid_names[] = { "/", ".", "..", NULL };

#define TFS_BITMAP_BLK_INVAL  0xffff
#define TFS_BITMAP_BLK_COUNT  (TFS_BLOCKSIZE << 3)
#define TFS_BITMAP_BLK_MASK   (TFS_BITMAP_BLK_COUNT - 1)
#define TFS_BITMAP_BLK_SHIFT  (TFS_BLOCKSIZE_WIDTH + 3)

#define GET_BITMAK_BLK(x) ((x) & ~TFS_BITMAP_BLK_MASK)

static uint32_t last_bitmap_blk;
static uint16_t last_bitmap_len;
static uint32_t loaded_bitmap_blk;
static uint8_t bitmap_blk[TFS_BLOCKSIZE];

static uint32_t current_dir_blk;
static uint32_t loaded_dir_blk;

static TFS_BLK_BUFFER blk_buf;

static void check_name(const char *name);
static void load_bitmap(uint32_t pos);
static uint32_t alloc_block(void);
static void free_block(uint32_t pos);
static void free_file_blocks(uint32_t pos);
static void init_dir(void);
static void write_dir_cleanup(void);
static TFS_DIR_ITEM *find_file(const char *name, uint8_t want_free_item);

static void check_name(const char *name) {
  const char **p;

  for (p = invalid_names; *p != NULL; p++) {
    if (strcmp(name, *p) == 0) {
      last_error = TFS_ERR_NAME_INVAL;
      return;
    }
  }
}

static void load_bitmap(uint32_t pos) {
  dev_read_block(pos, bitmap_blk);
  if (last_error != TFS_ERR_OK) {
    loaded_bitmap_blk = TFS_BITMAP_BLK_INVAL;
    return;
  }

  loaded_bitmap_blk = pos;
}

static uint32_t alloc_block(void) {
  uint32_t start, pos;
  uint32_t block;
  uint16_t i;
  uint8_t *p;
  uint8_t mask;

  // no current bitmap block -> full was detected
  if (loaded_bitmap_blk == TFS_BITMAP_BLK_INVAL) {
    last_error = TFS_ERR_DISK_FULL;
    return 0;
  }

  start = loaded_bitmap_blk;
  pos = loaded_bitmap_blk;
  while (1) {
    // serach for free block in current bitmap block
    for (i = 0, p = bitmap_blk, block = pos; i < TFS_BLOCKSIZE; i++, p++, block += 8) {
      if (*p != 0xff) {
        for (mask = 1; mask != 0; mask <<= 1, block++) {
          if ((*p & mask) == 0) {
            // free block found, mark as used
            *p |= mask;

            // write updated bitmap block
            dev_write_block(loaded_bitmap_blk, bitmap_blk);
            if (last_error != TFS_ERR_OK) {
              return 0;
            }

            return block;
          }
        }
      }
    }

    // no free block found, go to next one
    // turn around on end of disk
    if (pos == last_bitmap_blk) {
      pos = TFS_FIRST_BITMAP_BLK;
    } else {
      pos += TFS_BITMAP_BLK_COUNT;
    }

    // disk is full if we're back to where we have started
    if (pos == start) {
      loaded_bitmap_blk = TFS_BITMAP_BLK_INVAL;
      last_error = TFS_ERR_DISK_FULL;
      return 0;
    }

    // read next block
    load_bitmap(pos);
    if (last_error != TFS_ERR_OK) {
      return 0;
    }
  }
}

static void free_block(uint32_t pos) {
  uint32_t tmp;
  uint8_t mask;
  uint16_t offset;

  // load corrosponding bitmap block
  tmp = GET_BITMAK_BLK(pos);
  if (loaded_bitmap_blk != tmp) {
    load_bitmap(tmp);
    if (last_error != TFS_ERR_OK) {
      return;
    }
  }

  // mark block as unused
  offset = pos & TFS_BITMAP_BLK_MASK;
  mask = 1 << (offset & 0x07);
  offset >>= 3;
  bitmap_blk[offset] &= ~mask;

  // write block
  dev_write_block(loaded_bitmap_blk, bitmap_blk);
  if (last_error != TFS_ERR_OK) {
    return;
  }
}

static void free_file_blocks(uint32_t pos) {
  while (pos != 0) {
    dev_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }
    free_block(pos);
    if (last_error != TFS_ERR_OK) {
      return;
    }
    pos = blk_buf.data.next;
  }
}

static void init_dir(void) {
  current_dir_blk = TFS_ROOT_DIR_BLK;
  loaded_dir_blk = 0;
}

static void write_dir_cleanup(void) {
  uint8_t i;
  TFS_DIR_ITEM *p;
  uint32_t prev, next;

  // this block is the last one -> do normal write
  if (blk_buf.dir.prev == 0 && blk_buf.dir.next == 0) {
    dev_write_block(loaded_dir_blk, blk_buf.raw);
    return;
  }

  // check for completly empty directory block
  for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
    if (p->type != TFS_DIR_ITEM_FREE) {
      // not empty -> do normal write
      dev_write_block(loaded_dir_blk, blk_buf.raw);
      return;
    }
  }

  // remember pointers
  prev = blk_buf.dir.prev;
  next = blk_buf.dir.next;

  if (prev == 0) {
    // we are on list head, so move the next block to this position
    dev_read_block(next, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    blk_buf.dir.prev = 0;

    // exchange pointers
    prev = loaded_dir_blk;
    loaded_dir_blk = next;
    next = blk_buf.dir.next;
  } else {
    // update prev
    dev_read_block(prev, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    blk_buf.dir.next = next;
  }

  // write updated block
  dev_write_block(prev, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  if (next != 0) {
    // update next
    dev_read_block(next, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    blk_buf.dir.prev = prev;

    dev_write_block(next, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }
  }

  // free unused block
  free_block(loaded_dir_blk);
}

static TFS_DIR_ITEM *find_file(const char *name, uint8_t want_free_item) {
  uint32_t pos = current_dir_blk;
  uint8_t i;
  TFS_DIR_ITEM *p;
  uint32_t free_blk = 0;
  int8_t free_item = -1;

  // check for name
  if (*name == 0) {
    last_error = TFS_ERR_NO_NAME;
    return NULL;
  }

  while (1) {
    // read current directory block
    dev_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return NULL;
    }
    loaded_dir_blk = pos;

    // iterrate items
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
      if (p->type == TFS_DIR_ITEM_FREE) {
        // remember free item, if found one
        if (free_item < 0) {
          free_blk = pos;
          free_item = i;
        }
      } else {
        // check filename
        if (strncmp(name, p->name, TFS_NAME_LEN) == 0) {
          return p;
        }
      }
    }

    // go to next block in chain
    pos = blk_buf.dir.next;
    if (pos == 0) {
      break;
    }
  }

  // no match found and we do not want a free die item
  if (!want_free_item) {
    return NULL;
  }

  // free item found
  if (free_item >= 0) {
    // reload directory block, if an other than the one with the free item is loaded
    if (loaded_dir_blk != free_blk) {
      dev_read_block(free_blk, blk_buf.raw);
      if (last_error != TFS_ERR_OK) {
        return NULL;
      }
      loaded_dir_blk = free_blk;
    }

    return &blk_buf.dir.items[free_item];
  }

  // now we need a new directory block, so alloc one
  free_blk = alloc_block();
  if (last_error != TFS_ERR_OK) {
    return NULL;
  }

  // add pointer to new block to last one
  blk_buf.dir.next = free_blk;
  dev_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return NULL;
  }

  // initialize new block
  // keep some fields from the last one loaded (e.g. type, patent)
  blk_buf.dir.prev = loaded_dir_blk;
  blk_buf.dir.next = 0;
  memset(blk_buf.dir.items, 0, sizeof(TFS_DIR_ITEM) * TFS_DIR_BLK_ITEMS);
  loaded_dir_blk = free_blk;

  // write block
  dev_write_block(free_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return NULL;
  }

  return blk_buf.dir.items; // first item is free on new block
}

void tfs_init(void) {
  uint32_t last_blk;

  last_error = TFS_ERR_OK;

  last_blk = dev_info.blk_count - 1;
  last_bitmap_blk = GET_BITMAK_BLK(last_blk);
  last_bitmap_len = (last_blk & TFS_BITMAP_BLK_MASK) + 1;

  load_bitmap(TFS_FIRST_BITMAP_BLK);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  init_dir();
}

void tfs_format(void) {
  uint32_t pos;
  uint8_t mask, last;
  uint16_t offset;
  uint32_t prog_max = last_bitmap_blk >> TFS_BITMAP_BLK_SHIFT;

  last_error = TFS_ERR_OK;
  tfs_format_state(TFS_FORMAT_STATE_START);

  // write the bitmap-blocks
  // first block always in use (the bitmapblock itself)
  memset(&bitmap_blk, 0, TFS_BLOCKSIZE);
  bitmap_blk[0] = 1;
  pos = TFS_FIRST_BITMAP_BLK;
  last = 0;
  tfs_format_state(TFS_FORMAT_STATE_BITMAP_START);
  while(1) {
    // print progress
    tfs_format_progress(pos >> TFS_BITMAP_BLK_SHIFT, prog_max);

    if (pos == last_bitmap_blk) {
      last = 1;
      // mark all blocks after end of disk as used
      mask = 0xff << (last_bitmap_len & 0x07);
      offset = last_bitmap_len >> 3;
      bitmap_blk[offset] |= mask;
      for (offset++; offset < TFS_BLOCKSIZE; offset++) {
        bitmap_blk[offset] = 0xff;
      }
    }

    // write block
    dev_write_block(pos, bitmap_blk);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // break on last block
    if (last) {
      tfs_format_state(TFS_FORMAT_STATE_BITMAP_DONE);
      break;
    }

    // skip to next block
    pos += TFS_BITMAP_BLK_COUNT;
  };

  // read the first bitmap-block
  load_bitmap(TFS_FIRST_BITMAP_BLK);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  tfs_format_state(TFS_FORMAT_STATE_ROOTDIR);

  // alloc root dir block (should be block 3)
  pos = alloc_block();
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // init root directory
  memset(blk_buf.raw, 0, TFS_BLOCKSIZE);

  // write block
  dev_write_block(pos, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // read back root directory
  init_dir();

  tfs_format_state(TFS_FORMAT_STATE_DONE);
}

void tfs_read_dir(DIR_ITEM_HANDLER handler) {
  uint32_t pos = current_dir_blk;
  uint8_t i;
  TFS_DIR_ITEM *p;

  last_error = TFS_ERR_OK;

  while (1) {
    // read current directory block
    dev_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // iterrate items
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
      handler(p);
    }

    // go to next block in chain
    pos = blk_buf.dir.next;
    if (pos == 0) {
      break;
    }
  }
}

void tfs_change_dir(const char *name) {
  TFS_DIR_ITEM *item;

  last_error = TFS_ERR_OK;

  // go to root dir
  if (strcmp(name, "/") == 0) {
    current_dir_blk = TFS_ROOT_DIR_BLK;
    return;
  }

  // go to parent dir
  if (strcmp(name, "..") == 0) {
    dev_read_block(current_dir_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }
    if (blk_buf.dir.parent == 0) {
      last_error = TFS_ERR_NOT_EXIST;
      return;
    }
    current_dir_blk = blk_buf.dir.parent;
    return;
  }

  // search for dir name
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // directory not found?
  if (item == NULL || item->type != TFS_DIR_ITEM_DIR) {
    last_error = TFS_ERR_NOT_EXIST;
    return;
  }

  // set to found item
  current_dir_blk = item->blk;
}

void tfs_create_dir(const char *name) {
  TFS_DIR_ITEM *item;
  uint32_t new;

  last_error = TFS_ERR_OK;

  // check for invalid names
  check_name(name);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // check for name
  item = find_file(name, 1);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // directory already exists?
  if (item->type != TFS_DIR_ITEM_FREE) {
    last_error = TFS_ERR_DIR_EXIST;
    return;
  }

  // alloc new dir block
  new = alloc_block();
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // update item
  item->type = TFS_DIR_ITEM_DIR;
  item->blk = new;
  item->size = 0;
  strncpy(item->name, name, TFS_NAME_LEN);
  dev_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // init sub directory
  memset(blk_buf.raw, 0, TFS_BLOCKSIZE);
  blk_buf.dir.parent = current_dir_blk;

  // write block
  dev_write_block(new, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }
}

void tfs_write_file(const char *name, const void *data, uint16_t len, uint8_t overwrite) {
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint16_t blk_len;

  last_error = TFS_ERR_OK;

  // check for invalid names
  check_name(name);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // check for name
  item = find_file(name, 1);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // file already exists?
  if (item->type != TFS_DIR_ITEM_FREE) {
    if (!overwrite || item->type != TFS_DIR_ITEM_FILE) {
      last_error = TFS_ERR_FILE_EXIST;
      return;
    }
    // free old data blocks
    free_file_blocks(item->blk);
    if (last_error != TFS_ERR_OK) {
      return;
    }
  }

  if (len == 0) {
    // clear block pointer in case of overwrite
    pos = 0;
  } else {
    // allocate first data block
    pos = alloc_block();
    if (last_error != TFS_ERR_OK) {
      return;
    }
  }

  // update item
  item->type = TFS_DIR_ITEM_FILE;
  item->blk = pos;
  item->size = len;
  strncpy(item->name, name, TFS_NAME_LEN);
  dev_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // write data blocks
  while (pos != 0) {
    // calculate block length and update remaining length
    if (len > TFS_DATA_LEN) {
      blk_len = TFS_DATA_LEN;
      len -= TFS_DATA_LEN;

      // allocate next data block
      blk_buf.data.next = alloc_block();
      if (last_error != TFS_ERR_OK) {
        return;
      }
    } else {
      blk_len = len;
      len = 0;
      blk_buf.data.next = 0;
    }

    // copy user data
    memcpy(blk_buf.data.data, data, blk_len);
    data += blk_len;

    // write block
    dev_write_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    pos = blk_buf.data.next;
  }
}

uint16_t tfs_read_file(const char *name, void *data, uint16_t max_len) {
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint16_t len, rem, blk_len;

  last_error = TFS_ERR_OK;

  // search for file
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    return 0;
  }

  // file not found?
  if (item == NULL || item->type != TFS_DIR_ITEM_FILE) {
    last_error = TFS_ERR_NOT_EXIST;
    return 0;
  }

  // initialize loop
  pos = item->blk;
  len = item->size;
  if (len > max_len) {
    len = max_len;
  }

  rem = len;
  while (1) {
    // read next data block
    dev_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return 0;
    }

    // calculate block length and update remaining length
    if (rem > TFS_DATA_LEN) {
      blk_len = TFS_DATA_LEN;
      rem -= TFS_DATA_LEN;
    } else {
      blk_len = rem;
      rem = 0;
    }

    // copy user data
    memcpy(data, blk_buf.data.data, blk_len);
    data += blk_len;

    // go to next data block
    pos = blk_buf.data.next;
    if (pos == 0) {
      if (rem > 0) {
        last_error = TFS_ERR_UNEXP_EOF;
        return 0;
      }

      return len;
    }
  }
}

void tfs_delete(const char *name) {
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint8_t i;
  TFS_DIR_ITEM *p;

  last_error = TFS_ERR_OK;

  // search for name
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // not found?
  if (item == NULL) {
    last_error = TFS_ERR_NOT_EXIST;
    return;
  }

  // remember starting block
  pos = item->blk;

  // delete file
  if (item->type == TFS_DIR_ITEM_FILE) {
    // update item
    item->type = TFS_DIR_ITEM_FREE;
    write_dir_cleanup();
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // free data blocks
    free_file_blocks(pos);
    return;
  }

  // delete directory
  if (item->type == TFS_DIR_ITEM_DIR) {
    // read sub directory block
    dev_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // check if directory is empty
    if (blk_buf.dir.next != 0) {
      last_error = TFS_ERR_NOT_EMPTY;
      return;
    }
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
      if (p->type != TFS_DIR_ITEM_FREE) {
        last_error = TFS_ERR_NOT_EMPTY;
        return;
      }
    }

    // re-read parent directory block
    dev_read_block(loaded_dir_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // update item
    item->type = TFS_DIR_ITEM_FREE;
    write_dir_cleanup();
    if (last_error != TFS_ERR_OK) {
      return;
    }

    // free directory block
    free_block(pos);
    return;
  }

  last_error = TFS_ERR_NOT_EXIST;
}

