#include "filesys.h"

#include <string.h>

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

TFS_DRIVE_INFO drive_info;
uint8_t last_error;

#ifdef TFS_EXTENDED_API

typedef struct {
  uint8_t usage_count;
  uint32_t dir_blk;
  TFS_DIR_ITEM *dir_item;
  uint32_t size;
  uint32_t first_blk;
  uint32_t curr_blk;
  uint32_t curr_pos;
} TFS_FILEHANDLE;

static TFS_FILEHANDLE handles[TFS_MAX_FDS];

#define SEEK_ERROR  0
#define SEEK_OK     1
#define SEEK_EOF    2
#define SEEK_APPEND 3

static uint8_t item_usage_count(TFS_DIR_ITEM *item);
static void init_pos(TFS_FILEHANDLE *hnd);
static void update_dir_item(TFS_FILEHANDLE *hnd);
static uint8_t seek(TFS_FILEHANDLE *hnd, uint32_t pos, uint8_t append);

#endif

#define TFS_BITMAP_BLK_INVAL  0xffffffff
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

static void load_bitmap(uint32_t pos);
static uint32_t alloc_block(void);
static void free_block(uint32_t pos);
static void free_file_blocks(uint32_t pos);
static void write_dir_cleanup(void);
static TFS_DIR_ITEM *find_file(const char *name, uint8_t want_free_item);

static void load_bitmap(uint32_t pos) {
  drive_read_block(pos, bitmap_blk);
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
            drive_write_block(loaded_bitmap_blk, bitmap_blk);
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
  drive_write_block(loaded_bitmap_blk, bitmap_blk);
  if (last_error != TFS_ERR_OK) {
    return;
  }
}

static void free_file_blocks(uint32_t pos) {
  while (pos != 0) {
    drive_read_block(pos, blk_buf.raw);
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

static void write_dir_cleanup(void) {
  uint8_t i;
  TFS_DIR_ITEM *p;
  uint32_t prev, next;

  // this block is the last one -> do normal write
  if (blk_buf.dir.prev == 0 && blk_buf.dir.next == 0) {
    drive_write_block(loaded_dir_blk, blk_buf.raw);
    return;
  }

  // check for completly empty directory block
  for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
    if (p->type != TFS_DIR_ITEM_FREE) {
      // not empty -> do normal write
      drive_write_block(loaded_dir_blk, blk_buf.raw);
      return;
    }
  }

  // remember pointers
  prev = blk_buf.dir.prev;
  next = blk_buf.dir.next;

  if (prev == 0) {
    // we are on list head, so move the next block to this position
    drive_read_block(next, blk_buf.raw);
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
    drive_read_block(prev, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    blk_buf.dir.next = next;
  }

  // write updated block
  drive_write_block(prev, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  if (next != 0) {
    // update next
    drive_read_block(next, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return;
    }

    blk_buf.dir.prev = prev;

    drive_write_block(next, blk_buf.raw);
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
    drive_read_block(pos, blk_buf.raw);
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
      drive_read_block(free_blk, blk_buf.raw);
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
  drive_write_block(loaded_dir_blk, blk_buf.raw);
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
  drive_write_block(free_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return NULL;
  }

  return blk_buf.dir.items; // first item is free on new block
}

void tfs_init(void) {

#ifdef TFS_EXTENDED_API
  memset(handles, 0, sizeof(handles));
#endif

  last_error = TFS_ERR_OK;
  drive_select();

  last_bitmap_blk = drive_info.blk_count - 1;
  last_bitmap_len = (last_bitmap_len & TFS_BITMAP_BLK_MASK) + 1;
  last_bitmap_blk = GET_BITMAK_BLK(last_bitmap_blk);

  load_bitmap(TFS_FIRST_BITMAP_BLK);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  current_dir_blk = TFS_ROOT_DIR_BLK;
  loaded_dir_blk = 0;
out:
  drive_deselect();
}

#ifdef TFS_ENABLE_FORMAT
void tfs_format(void) {
  uint32_t pos;
  uint8_t mask, last;
  uint16_t offset;
#ifdef TFS_FORMAT_STATE_CALLBACK
  uint32_t prog_max = last_bitmap_blk >> TFS_BITMAP_BLK_SHIFT;
#endif

  last_error = TFS_ERR_OK;
#ifdef TFS_FORMAT_STATE_CALLBACK
  tfs_format_state(TFS_FORMAT_STATE_START);
#endif

  drive_select();

  // write the bitmap-blocks
  // first block always in use (the bitmapblock itself)
  memset(&bitmap_blk, 0, TFS_BLOCKSIZE);
  bitmap_blk[0] = 1;
  pos = TFS_FIRST_BITMAP_BLK;
  last = 0;
#ifdef TFS_FORMAT_STATE_CALLBACK
  tfs_format_state(TFS_FORMAT_STATE_BITMAP_START);
#endif
  while(1) {
#ifdef TFS_FORMAT_STATE_CALLBACK
    // print progress
    tfs_format_progress(pos >> TFS_BITMAP_BLK_SHIFT, prog_max);
#endif

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
    drive_write_block(pos, bitmap_blk);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // break on last block
    if (last) {
#ifdef TFS_FORMAT_STATE_CALLBACK
      tfs_format_state(TFS_FORMAT_STATE_BITMAP_DONE);
#endif
      break;
    }

    // skip to next block
    pos += TFS_BITMAP_BLK_COUNT;
  };

  // read the first bitmap-block
  load_bitmap(TFS_FIRST_BITMAP_BLK);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

#ifdef TFS_FORMAT_STATE_CALLBACK
  tfs_format_state(TFS_FORMAT_STATE_ROOTDIR);
#endif

  // alloc root dir block (should be block 3)
  pos = alloc_block();
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // init root directory
  memset(blk_buf.raw, 0, TFS_BLOCKSIZE);

  // write block
  drive_write_block(pos, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  current_dir_blk = TFS_ROOT_DIR_BLK;
  loaded_dir_blk = 0;

#ifdef TFS_FORMAT_STATE_CALLBACK
  tfs_format_state(TFS_FORMAT_STATE_DONE);
#endif

out:
  drive_deselect();
}
#endif

uint32_t tfs_get_used(void) {
  uint32_t pos, used;
  uint16_t i;
  uint8_t *p;
  uint8_t mask;

  last_error = TFS_ERR_OK;
  drive_select();

  pos = TFS_FIRST_BITMAP_BLK;
  used = 0;
  while (1) {
    // load bitmap block
    load_bitmap(pos);
    if (last_error != TFS_ERR_OK) {
      drive_deselect();
      return 0;
    }

    // count allocated blocks
    for (i = 0, p = bitmap_blk; i < TFS_BLOCKSIZE; i++, p++) {
      if (*p > 0) {
        for (mask = 1; mask != 0; mask <<= 1) {
          if ((*p & mask) != 0) {
            used++;
          }
        }
      }
    }

    // check for end of list
    if (pos == last_bitmap_blk) {
      load_bitmap(TFS_FIRST_BITMAP_BLK);
      drive_deselect();
      // blocks after dist end are marked as use, so substract them
      return used - (TFS_BITMAP_BLK_COUNT - last_bitmap_len);
    }

    // next block
    pos += TFS_BITMAP_BLK_COUNT;
  }
}

#ifdef TFS_READ_DIR_USERDATA
uint8_t tfs_read_dir(TFS_READ_DIR_USERDATA data) {
#else
uint8_t tfs_read_dir(void) {
#endif
  uint32_t pos = current_dir_blk;
  uint8_t i;
  uint8_t done = 0;
  TFS_DIR_ITEM *p;

  last_error = TFS_ERR_OK;
  drive_select();

  while (1) {
    // read current directory block
    drive_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // iterrate items
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
#ifdef TFS_READ_DIR_USERDATA
      if (!tfs_dir_handler(data, p)) {
#else
      if (!tfs_dir_handler(p)) {
#endif
        goto out;
      }
    }

    // go to next block in chain
    pos = blk_buf.dir.next;
    if (pos == 0) {
      done = 1;
      break;
    }
  }
out:
  drive_deselect();
  return done;
}

void tfs_change_dir_root(void) {
  current_dir_blk = TFS_ROOT_DIR_BLK;
}

void tfs_change_dir_parent(void) {
  last_error = TFS_ERR_OK;
  drive_select();

  drive_read_block(current_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  if (blk_buf.dir.parent == 0) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

  current_dir_blk = blk_buf.dir.parent;

out:
  drive_deselect();
}

void tfs_change_dir(const char *name) {
  TFS_DIR_ITEM *item;

  last_error = TFS_ERR_OK;
  drive_select();

  // search for dir name
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // directory not found?
  if (item == NULL || item->type != TFS_DIR_ITEM_DIR) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

  // set to found item
  current_dir_blk = item->blk;
out:
  drive_deselect();
}

void tfs_create_dir(const char *name) {
  TFS_DIR_ITEM *item;
  uint32_t new;

  last_error = TFS_ERR_OK;
  drive_select();

  // check for name
  item = find_file(name, 1);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // directory already exists?
  if (item->type != TFS_DIR_ITEM_FREE) {
    last_error = TFS_ERR_FILE_EXIST;
    goto out;
  }

  // alloc new dir block
  new = alloc_block();
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // update item
  item->type = TFS_DIR_ITEM_DIR;
  item->blk = new;
  item->size = 0;
  strncpy(item->name, name, TFS_NAME_LEN);
  drive_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // init sub directory
  memset(blk_buf.raw, 0, TFS_BLOCKSIZE);
  blk_buf.dir.parent = current_dir_blk;

  // write block
  drive_write_block(new, blk_buf.raw);
out:
  drive_deselect();
}

void tfs_write_file(const char *name, const uint8_t *data, uint32_t len, uint8_t overwrite) {
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint16_t blk_len;

  last_error = TFS_ERR_OK;
  drive_select();

  // check for name
  item = find_file(name, 1);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file already exists?
  if (item->type != TFS_DIR_ITEM_FREE) {
    if (!overwrite || item->type != TFS_DIR_ITEM_FILE) {
      last_error = TFS_ERR_FILE_EXIST;
      goto out;
    }

#ifdef TFS_EXTENDED_API
    // check if file is in use
    if (item_usage_count(item) > 0) {
      last_error = TFS_FILE_BUSY;
      goto out;
    }
#endif

    // free old data blocks
    free_file_blocks(item->blk);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }
  }

  if (len == 0) {
    // clear block pointer in case of overwrite
    pos = 0;
  } else {
    // allocate first data block
    pos = alloc_block();
    if (last_error != TFS_ERR_OK) {
      goto out;
    }
  }

  // update item
  item->type = TFS_DIR_ITEM_FILE;
  item->blk = pos;
  item->size = len;
  strncpy(item->name, name, TFS_NAME_LEN);
  drive_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // write data blocks
  blk_buf.data.prev = 0;
  while (pos != 0) {
    // calculate block length and update remaining length
    if (len > TFS_DATA_LEN) {
      blk_len = TFS_DATA_LEN;
      len -= TFS_DATA_LEN;

      // allocate next data block
      blk_buf.data.next = alloc_block();
      // if error -> try to write the last data block, error is handled after write
    } else {
      blk_len = len;
      len = 0;
      blk_buf.data.next = 0;
    }

    // copy user data
    memcpy(blk_buf.data.data, data, blk_len);
    data += blk_len;

    // write block
    drive_write_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    blk_buf.data.prev = pos;
    pos = blk_buf.data.next;
  }
out:
  drive_deselect();
}

uint32_t tfs_read_file(const char *name, uint8_t *data, uint32_t max_len) {
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint32_t len = 0;
  uint32_t rem;
  uint16_t blk_len;

  last_error = TFS_ERR_OK;
  drive_select();

  // search for file
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file not found?
  if (item == NULL || item->type != TFS_DIR_ITEM_FILE) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
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
    drive_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
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
        goto out;
      }

      goto out;
    }
  }
out:
  drive_deselect();
  return len;
}

#ifdef TFS_EXTENDED_API
void tfs_delete(const char *name, uint8_t type) {
#else
void tfs_delete(const char *name) {
#endif
  TFS_DIR_ITEM *item;
  uint32_t pos;
  uint8_t i;
  TFS_DIR_ITEM *p;

  last_error = TFS_ERR_OK;
  drive_select();

  // search for name
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // not found?
  if (item == NULL) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

#ifdef TFS_EXTENDED_API
  // check file type
  if (type != 0 && item->type != type) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

  // check if file is in use
  if (item_usage_count(item) > 0) {
    last_error = TFS_FILE_BUSY;
    goto out;
  }
#endif

  // remember starting block
  pos = item->blk;

  // delete file
  if (item->type == TFS_DIR_ITEM_FILE) {
    // update item
    item->type = TFS_DIR_ITEM_FREE;
    write_dir_cleanup();
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // free data blocks
    free_file_blocks(pos);
    goto out;
  }

  // delete directory
  if (item->type == TFS_DIR_ITEM_DIR) {
    // read sub directory block
    drive_read_block(pos, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // check if directory is empty
    if (blk_buf.dir.next != 0) {
      last_error = TFS_ERR_NOT_EMPTY;
      goto out;
    }
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
      if (p->type != TFS_DIR_ITEM_FREE) {
        last_error = TFS_ERR_NOT_EMPTY;
        goto out;
      }
    }

    // re-read parent directory block
    drive_read_block(loaded_dir_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // update item
    item->type = TFS_DIR_ITEM_FREE;
    write_dir_cleanup();
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // free directory block
    free_block(pos);
    goto out;
  }

  last_error = TFS_ERR_NOT_EXIST;
out:
  drive_deselect();
}

void tfs_rename(const char *from, const char *to) {
  TFS_DIR_ITEM *item;

  last_error = TFS_ERR_OK;
  drive_select();

  // check if 'to name' already exists
  item = find_file(to, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file already exists?
  if (item != NULL) {
    last_error = TFS_ERR_FILE_EXIST;
    goto out;
  }

  // find 'from name' item
  item = find_file(from, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file not exists?
  if (item == NULL) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

  // update item
  strncpy(item->name, to, TFS_NAME_LEN);
  drive_write_block(loaded_dir_blk, blk_buf.raw);

out:
  drive_deselect();
}

#ifdef TFS_EXTENDED_API

static uint8_t item_usage_count(TFS_DIR_ITEM *item) {
  TFS_FILEHANDLE *hnd;
  int8_t fd;

  for (fd = 0, hnd = handles; fd < TFS_MAX_FDS; fd++, hnd++) {
    if (hnd->dir_blk == loaded_dir_blk && hnd->dir_item == item) {
      return hnd->usage_count;
    }
  }

  return 0;
}

static void init_pos(TFS_FILEHANDLE *hnd) {
  hnd->curr_blk = hnd->first_blk;
  hnd->curr_pos = 0;
}

static void update_dir_item(TFS_FILEHANDLE *hnd) {
  // read file's directory block
  drive_read_block(hnd->dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    return;
  }

  // update item
  hnd->dir_item->blk = hnd->first_blk;
  hnd->dir_item->size = hnd->size;
  drive_write_block(hnd->dir_blk, blk_buf.raw);
}

static uint8_t seek(TFS_FILEHANDLE *hnd, uint32_t pos, uint8_t append) {
  uint32_t last_blk = 0;
  uint32_t last_pos = 0;

  // go to start position
  if (pos == 0 || hnd->curr_blk == 0) {
    init_pos(hnd);
  }

  // seek backward, till we are in requested block
  while (hnd->curr_blk != 0 && hnd->curr_pos > pos) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    // fail, if we have no prev block
    if (blk_buf.data.prev == 0) {
      last_error = TFS_ERR_UNEXP_EOF;
      return SEEK_ERROR;
    }

    hnd->curr_blk = blk_buf.data.prev;
    hnd->curr_pos -= TFS_DATA_LEN;
  }

  // seek forward, till we are in requested block
  while (hnd->curr_blk != 0 && (hnd->curr_pos + TFS_DATA_LEN) <= pos) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    // remember last valid block
    last_blk = hnd->curr_blk;
    last_pos = hnd->curr_pos;

    hnd->curr_blk = blk_buf.data.next;
    hnd->curr_pos += TFS_DATA_LEN;
  }

  if (hnd->curr_blk != 0) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    return SEEK_OK;
  }

  // now append is needed
  if (!append) {
    return SEEK_EOF;
  }

  // check for valid first block
  if (hnd->first_blk == 0) {
    // allocate first block
    hnd->first_blk = alloc_block();
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    memset(blk_buf.raw, 0, TFS_BLOCKSIZE);

    init_pos(hnd);
    last_blk = hnd->curr_blk;
    last_pos = hnd->curr_pos;
  }

  hnd->curr_blk = last_blk;
  hnd->curr_pos = last_pos;
  while ((hnd->curr_pos + TFS_DATA_LEN) <= pos) {
    // allocate next block
    blk_buf.data.next = alloc_block();
    // if error -> try to write the last data block, error is handled after write

    // update pointer
    drive_write_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    // next block data must be initialized with zeros
    memset(blk_buf.data.data, 0, TFS_DATA_LEN);

    blk_buf.data.prev = hnd->curr_blk;
    hnd->curr_blk = blk_buf.data.next;
    blk_buf.data.next = 0;
    hnd->curr_pos += TFS_DATA_LEN;
  }

  // caller must write the current datablock and call update_dir_item
  return SEEK_APPEND;
}

TFS_DIR_ITEM *tfs_stat(const char *name) {
  TFS_DIR_ITEM *item;

  last_error = TFS_ERR_OK;
  drive_select();

  item = find_file(name, 0);

  drive_deselect();
  return item;
}

void tfs_touch(const char *name) {
  TFS_DIR_ITEM *item;

  last_error = TFS_ERR_OK;
  drive_select();

  // check for name
  item = find_file(name, 1);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file already exists?
  if (item->type != TFS_DIR_ITEM_FREE) {
    goto out;
  }

  // update item
  item->type = TFS_DIR_ITEM_FILE;
  item->blk = 0;
  item->size = 0;
  strncpy(item->name, name, TFS_NAME_LEN);
  drive_write_block(loaded_dir_blk, blk_buf.raw);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

out:
  drive_deselect();
}

int8_t tfs_open(const char *name) {
  TFS_FILEHANDLE *hnd;
  TFS_DIR_ITEM *item;
  int8_t fd = -1;

  last_error = TFS_ERR_OK;
  drive_select();

  // search for file
  item = find_file(name, 0);
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // file not found?
  if (item == NULL || item->type != TFS_DIR_ITEM_FILE) {
    last_error = TFS_ERR_NOT_EXIST;
    goto out;
  }

  // search for existing handle
  for (fd = 0, hnd = handles; fd < TFS_MAX_FDS; fd++, hnd++) {
    if (hnd->dir_blk == loaded_dir_blk && hnd->dir_item == item && hnd->usage_count > 0) {
      (hnd->usage_count)++;
      goto out;
    }
  }

  // search for empty handle
  for (fd = 0, hnd = handles; hnd->usage_count > 0; fd++, hnd++) {
    if (fd == TFS_MAX_FDS) {
      last_error = TFS_ERR_NO_FREE_FD;
      fd = -1;
      goto out;
    }
  }

  // initialize handle
  hnd->usage_count = 1;
  hnd->dir_blk = loaded_dir_blk;
  hnd->dir_item = item;
  hnd->size = item->size;
  hnd->first_blk = item->blk;
  init_pos(hnd);

out:
  drive_deselect();
  return fd;
}

void tfs_close(int8_t fd) {
  TFS_FILEHANDLE *hnd;

  last_error = TFS_ERR_OK;

  // check fd range
  if (fd < 0 && fd >= TFS_MAX_FDS) {
    last_error = TFS_ERR_INVAL_FD;
    return;
  }

  // check for valid handle
  hnd = &handles[fd];
  if (hnd->usage_count <= 0) {
    last_error = TFS_ERR_INVAL_FD;
    return;
  }

  // decrement usage counter
  (hnd->usage_count)--;
}

void tfs_trunc(int8_t fd, uint32_t size) {
  TFS_FILEHANDLE *hnd;
  uint8_t seek_res;
  uint32_t free_from = 0;

  last_error = TFS_ERR_OK;
  drive_select();

  // check fd range
  if (fd < 0 && fd >= TFS_MAX_FDS) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  // check for valid handle
  hnd = &handles[fd];
  if (hnd->usage_count <= 0) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  if (size == 0) {
    // simple case: free all
    free_file_blocks(hnd->first_blk);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    hnd->first_blk = 0;
    init_pos(hnd);
  } else {
    // expand file, if required
    seek_res = seek(hnd, size, 1);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // check, if we have to free remaining blocks
    if (seek_res == SEEK_OK) {
      free_from = blk_buf.data.next;
      blk_buf.data.next = 0;
    }

    // save the last block
    if (seek_res == SEEK_APPEND || free_from != 0) {
      drive_write_block(hnd->curr_blk, blk_buf.raw);
      if (last_error != TFS_ERR_OK) {
        goto out;
      }
    }

    // free remaining blocks
    free_file_blocks(free_from);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }
  }

  // update directory
  update_dir_item(hnd);

out:
  drive_deselect();
}

uint32_t tfs_write(int8_t fd, const uint8_t *data, uint32_t len, uint32_t offset) {
  TFS_FILEHANDLE *hnd;
  uint32_t blk_os, blk_len;
  uint8_t append = 0;
  uint8_t update_item = 0;
  uint32_t ret = 0;

  last_error = TFS_ERR_OK;
  drive_select();

  // check fd range
  if (fd < 0 && fd >= TFS_MAX_FDS) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  // check for valid handle
  hnd = &handles[fd];
  if (hnd->usage_count <= 0) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  // seek to position
  if (seek(hnd, offset, 1) == SEEK_APPEND) {
    append = 1;
    update_item = 1;
  }
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // something to write?
  if (len == 0) {
    goto update;
  }

  // write data
  blk_os = offset - hnd->curr_pos;
  blk_len = TFS_DATA_LEN - blk_os;
  while (1) {
    if (blk_len > len) {
      blk_len = len;
    }
    memcpy(blk_buf.data.data + blk_os, data, blk_len);

    data += blk_len;
    len -= blk_len;
    offset += blk_len;
    ret += blk_len;

    // prealloc next block
    if (len > 0 && blk_buf.data.next == 0) {
      // allocate next block
      blk_buf.data.next = alloc_block();
      // if error -> try to write the last data block, error is handled after write
      append = 1;
    }

    // write block
    drive_write_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      goto out;
    }

    // update file size
    if (offset > hnd->size) {
      hnd->size = offset;
      update_item = 1;
    }

    if (len == 0) {
      break;
    }

    // get next block
    if (append) {
      blk_buf.data.prev = hnd->curr_blk;
      hnd->curr_blk = blk_buf.data.next;
      blk_buf.data.next = 0;
      memset(blk_buf.data.data, 0, TFS_DATA_LEN);
    } else {
      hnd->curr_blk = blk_buf.data.next;
      drive_read_block(hnd->curr_blk, blk_buf.raw);
      if (last_error != TFS_ERR_OK) {
        return SEEK_ERROR;
      }
    }
    hnd->curr_pos += TFS_DATA_LEN;

    // reset start offset
    blk_os = 0;
    blk_len = TFS_DATA_LEN;
  }

update:
  // update directry
  if (update_item) {
    update_dir_item(hnd);
  }

out:
  drive_deselect();
  return ret;

}

uint32_t tfs_read(int8_t fd, uint8_t *data, uint32_t len, uint32_t offset) {
  TFS_FILEHANDLE *hnd;
  uint32_t blk_os, blk_len;

  uint32_t ret = 0;

  last_error = TFS_ERR_OK;
  drive_select();

  // check fd range
  if (fd < 0 && fd >= TFS_MAX_FDS) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  // check for valid handle
  hnd = &handles[fd];
  if (hnd->usage_count <= 0) {
    last_error = TFS_ERR_INVAL_FD;
    goto out;
  }

  // check file length
  if (offset > hnd->size) {
    goto out;
  }

  // limit length to remaining file size
  blk_len = hnd->size - offset;
  if (len > blk_len) {
    len = blk_len;
  }

  // seek to position
  if (seek(hnd, offset, 0) == SEEK_EOF) {
    goto out;
  }
  if (last_error != TFS_ERR_OK) {
    goto out;
  }

  // something to read?
  if (len == 0) {
    goto out;
  }

  // read data
  blk_os = offset - hnd->curr_pos;
  blk_len = TFS_DATA_LEN - blk_os;
  while (1) {
    if (blk_len > len) {
      blk_len = len;
    }
    memcpy(data, blk_buf.data.data + blk_os, blk_len);

    data += blk_len;
    len -= blk_len;
    ret += blk_len;

    if (len == 0) {
      break;
    }

    // get next block
    hnd->curr_blk = blk_buf.data.next;
    hnd->curr_pos += TFS_DATA_LEN;
    if (hnd->curr_blk == 0) {
      break;
    }

    // read block
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    if (last_error != TFS_ERR_OK) {
      return SEEK_ERROR;
    }

    // reset start offset
    blk_os = 0;
    blk_len = TFS_DATA_LEN;
  }

out:
  drive_deselect();
  return ret;
}

#endif

