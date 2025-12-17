# TinyFS Internal Design

This document describes the internal implementation details of TinyFS. It is intended for developers who want to understand or modify the filesystem code.

## Table of Contents

- [Module Overview](#module-overview)
- [Block Buffer Management](#block-buffer-management)
- [Bitmap Management](#bitmap-management)
- [Block Allocation Algorithm](#block-allocation-algorithm)
- [Block Freeing](#block-freeing)
- [Directory Search](#directory-search)
- [Directory Cleanup](#directory-cleanup)
- [Extended API Internals](#extended-api-internals)
- [Code Organization](#code-organization)

---

## Module Overview

TinyFS consists of a single-file implementation (`filesys.c`) with minimal external dependencies. The code is organized into several logical sections:

1. **Static data and buffers** - Global state and working buffers
2. **Internal helper functions** - Bitmap, allocation, directory operations
3. **Public API functions** - User-facing filesystem operations
4. **Extended API functions** - Optional file descriptor operations

### Key Design Principles

- **No dynamic allocation**: All memory is statically allocated
- **Minimal state**: Only essential state is maintained
- **Direct I/O**: No caching layer (keeps code simple)
- **Block reuse**: Single buffer reused for different block types

---

## Block Buffer Management

### The Unified Block Buffer

TinyFS uses a single 512-byte buffer (`blk_buf`) that can be interpreted as different block types:

```c
typedef union {
  uint8_t raw[TFS_BLOCKSIZE];    // Raw byte access
  TFS_DIR_BLK dir;               // Directory block interpretation
  TFS_DATA_BLK data;             // Data block interpretation
} TFS_BLK_BUFFER;

static TFS_BLK_BUFFER blk_buf;
```

This union allows the same memory to be used for:
- Reading/writing raw blocks
- Accessing directory structure (prev/next/parent/items)
- Accessing data block structure (prev/next/data)

**Advantages:**
- Saves 512 bytes of RAM (no separate buffers)
- Automatic type conversion
- Cache-friendly (single buffer location)

**Risks:**
- Must track which block is currently loaded
- Easy to accidentally overwrite with wrong operation
- Must reload after operations that modify buffer

### Buffer Tracking Variables

```c
static uint32_t loaded_dir_blk;    // Which directory block is in blk_buf
```

When a directory block is loaded, `loaded_dir_blk` is set to its block number. This allows:
- Avoiding redundant reads of the same block
- Knowing which block to write back after modifications
- Detecting when buffer contains stale data

**Important:** The bitmap has its own dedicated buffer (`bitmap_blk`) to avoid conflicts.

---

## Bitmap Management

### Bitmap Block Buffer

The bitmap is kept in a separate dedicated buffer:

```c
static uint8_t bitmap_blk[TFS_BLOCKSIZE];     // Current bitmap block (512 bytes)
static uint32_t loaded_bitmap_blk;            // Which bitmap block is loaded
```

This separation is crucial because:
1. Bitmap operations happen frequently during allocation
2. We need both directory and bitmap data simultaneously
3. Avoids constant reloading of bitmap during file operations

### Bitmap Loading

```c
static void load_bitmap(uint32_t pos) {
  drive_read_block(pos, bitmap_blk);
  if (tfs_last_error != TFS_ERR_OK) {
    loaded_bitmap_blk = TFS_BITMAP_BLK_INVAL;
    return;
  }
  loaded_bitmap_blk = pos;
}
```

**Key points:**
- Reads entire 512-byte bitmap block
- Updates `loaded_bitmap_blk` to track what's loaded
- On error, sets `loaded_bitmap_blk` to invalid (0xFFFFFFFF)
- Invalid bitmap indicates disk full state

### Bitmap Block Calculation

Given any block number, find its bitmap block:

```c
#define TFS_BITMAP_BLK_MASK   (TFS_BITMAP_BLK_COUNT - 1)  // 0x0FFF
#define GET_BITMAK_BLK(x)     ((x) & ~TFS_BITMAP_BLK_MASK)  // Note: typo in original code

// Example: Block 5432
// 5432 & ~0x0FFF = 5432 & 0xFFFFF000 = 4096
// So block 5432 is tracked by bitmap block 4096
```

This works because:
- Bitmap blocks are at multiples of 4096 (0, 4096, 8192, ...)
- Each bitmap tracks blocks [N*4096 ... (N+1)*4096-1]
- Bitwise AND with inverted mask rounds down to nearest 4096

### Bitmap Bit Manipulation

Finding and setting a free bit:

```c
// Iterate through bytes
for (i = 0, p = bitmap_blk, block = pos; i < TFS_BLOCKSIZE; i++, p++, block += 8) {
  if (*p != 0xff) {  // This byte has at least one free bit
    // Check each bit
    for (mask = 1; mask != 0; mask <<= 1, block++) {
      if ((*p & mask) == 0) {  // Found free bit
        *p |= mask;             // Mark as used
        // Write updated bitmap
        drive_write_block(loaded_bitmap_blk, bitmap_blk);
        return block;
      }
    }
  }
}
```

**Optimization:** Check byte first (0xff = all used), then check individual bits.

---

## Block Allocation Algorithm

The `alloc_block()` function implements a circular search starting from the currently loaded bitmap:

```c
static uint32_t alloc_block(void) {
  uint32_t start, pos;
  
  // Check if we're in "disk full" state
  if (loaded_bitmap_blk == TFS_BITMAP_BLK_INVAL) {
    tfs_last_error = TFS_ERR_DISK_FULL;
    return 0;
  }
  
  start = loaded_bitmap_blk;  // Remember where we started
  pos = loaded_bitmap_blk;
  
  while (1) {
    // Search current bitmap block for free bit
    // ... (bit search code) ...
    
    // No free block in this bitmap, move to next
    if (pos == last_bitmap_blk) {
      pos = TFS_FIRST_BITMAP_BLK;  // Wrap around
    } else {
      pos += TFS_BITMAP_BLK_COUNT;  // Next bitmap
    }
    
    // Back where we started = disk is full
    if (pos == start) {
      loaded_bitmap_blk = TFS_BITMAP_BLK_INVAL;
      tfs_last_error = TFS_ERR_DISK_FULL;
      return 0;
    }
    
    // Load next bitmap block
    load_bitmap(pos);
    if (tfs_last_error != TFS_ERR_OK) {
      return 0;
    }
  }
}
```

### Algorithm Properties

**Time Complexity:**
- Best case: O(1) - free bit in current bitmap
- Worst case: O(n) - must scan all bitmap blocks
- Average: O(1) - free bits usually available in current bitmap

**Space Locality:**
- Allocations tend to cluster in same region
- Reduces fragmentation
- Better for sequential operations

**Caching Strategy:**
- Keeps successful bitmap loaded
- Next allocation likely from same bitmap
- Minimizes disk reads

---

## Block Freeing

### Single Block Free

```c
static void free_block(uint32_t pos) {
  uint32_t tmp;
  uint8_t mask;
  uint16_t offset;
  
  // Find which bitmap block tracks this block
  tmp = GET_BITMAK_BLK(pos);
  
  // Load it if not already loaded
  if (loaded_bitmap_blk != tmp) {
    load_bitmap(tmp);
    if (tfs_last_error != TFS_ERR_OK) {
      return;
    }
  }
  
  // Calculate bit position within bitmap
  offset = pos & TFS_BITMAP_BLK_MASK;  // Which bit (0-4095)
  mask = 1 << (offset & 0x07);          // Which bit in byte (0-7)
  offset >>= 3;                         // Which byte (0-511)
  
  // Clear the bit
  bitmap_blk[offset] &= ~mask;
  
  // Write back
  drive_write_block(loaded_bitmap_blk, bitmap_blk);
}
```

**Key optimization:** Check if bitmap already loaded before reading.

### Freeing File Blocks

```c
static void free_file_blocks(uint32_t pos) {
  while (pos != 0) {
    // Read block to get next pointer
    drive_read_block(pos, blk_buf.raw);
    if (tfs_last_error != TFS_ERR_OK) {
      return;
    }
    
    // Free current block
    free_block(pos);
    if (tfs_last_error != TFS_ERR_OK) {
      return;
    }
    
    // Move to next block in chain
    pos = blk_buf.data.next;
  }
}
```

**Note:** This overwrites `blk_buf`, so callers must reload directory block if needed.

---

## Directory Search

The `find_file()` function searches for a filename or finds a free directory entry:

```c
static TFS_DIR_ITEM *find_file(const char *name, uint8_t want_free_item) {
  uint32_t pos = current_dir_blk;
  uint8_t i;
  TFS_DIR_ITEM *p;
  uint32_t free_blk = 0;
  int8_t free_item = -1;
  
  // Check for empty name
  if (*name == 0) {
    tfs_last_error = TFS_ERR_NO_NAME;
    return NULL;
  }
  
  // Scan all directory blocks in chain
  while (1) {
    drive_read_block(pos, blk_buf.raw);
    if (tfs_last_error != TFS_ERR_OK) {
      return NULL;
    }
    loaded_dir_blk = pos;
    
    // Check all items in this block
    for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
      if (p->type == TFS_DIR_ITEM_FREE) {
        // Remember first free slot found
        if (free_item < 0) {
          free_blk = pos;
          free_item = i;
        }
      } else {
        // Check if name matches
        if (TFS_FILENAME_CMP(name, p->name)) {
          return p;  // Found it!
        }
      }
    }
    
    // Move to next block in chain
    pos = blk_buf.dir.next;
    if (pos == 0) {
      break;  // End of chain
    }
  }
  
  // Not found - return free slot if requested
  if (!want_free_item) {
    return NULL;
  }
  
  // ... allocation of new block if no free slot ...
}
```

### Search Algorithm Properties

**Single-pass:** One scan finds both the target and a free slot.

**Early termination:** Returns immediately when file is found.

**Lazy allocation:** Only allocates new directory block if no free slots exist.

### Free Slot Strategy

The function remembers the *first* free slot encountered during search. This means:
- Reuses slots from deleted files
- Minimizes directory fragmentation
- Prefers earlier blocks in chain

If no free slot exists, it allocates a new directory block:

```c
// Allocate new directory block
free_blk = alloc_block();
if (tfs_last_error != TFS_ERR_OK) {
  return NULL;
}

// Link it to the chain
blk_buf.dir.next = free_blk;
drive_write_block(loaded_dir_blk, blk_buf.raw);

// Initialize new block
blk_buf.dir.prev = loaded_dir_blk;
blk_buf.dir.next = 0;
memset(blk_buf.dir.items, 0, sizeof(TFS_DIR_ITEM) * TFS_DIR_BLK_ITEMS);
loaded_dir_blk = free_blk;

drive_write_block(free_blk, blk_buf.raw);

return blk_buf.dir.items;  // First item is free
```

---

## Directory Cleanup

The `write_dir_cleanup()` function optimizes directory storage by removing completely empty blocks:

```c
static void write_dir_cleanup(void) {
  uint8_t i;
  TFS_DIR_ITEM *p;
  uint32_t prev, next;
  
  // If this is the only block, just write it normally
  if (blk_buf.dir.prev == 0 && blk_buf.dir.next == 0) {
    drive_write_block(loaded_dir_blk, blk_buf.raw);
    return;
  }
  
  // Check if block is completely empty
  for (i = 0, p = blk_buf.dir.items; i < TFS_DIR_BLK_ITEMS; i++, p++) {
    if (p->type != TFS_DIR_ITEM_FREE) {
      // Has content, write normally
      drive_write_block(loaded_dir_blk, blk_buf.raw);
      return;
    }
  }
  
  // Block is empty, remove it from chain
  // ... (pointer manipulation) ...
}
```

### Cleanup Strategy

**When:** Called after marking a directory item as FREE.

**What:** If the entire block becomes empty, remove it from the linked list.

**Why:** Prevents wasted space from accumulated deletions.

### Special Cases

**First block in chain:**
```c
if (prev == 0) {
  // Move next block to current position
  drive_read_block(next, blk_buf.raw);
  blk_buf.dir.prev = 0;
  // Exchange pointers
  prev = loaded_dir_blk;
  loaded_dir_blk = next;
  next = blk_buf.dir.next;
}
```

**Middle or last block:**
```c
else {
  // Update prev block's next pointer
  drive_read_block(prev, blk_buf.raw);
  blk_buf.dir.next = next;
}

// Update next block's prev pointer (if exists)
if (next != 0) {
  drive_read_block(next, blk_buf.raw);
  blk_buf.dir.prev = prev;
  drive_write_block(next, blk_buf.raw);
}

// Free the removed block
free_block(loaded_dir_blk);
```

---

## Extended API Internals

The Extended API adds file handle management for random access operations.

### File Handle Structure

```c
typedef struct {
  uint8_t usage_count;     // Reference count (0 = unused)
  uint32_t dir_blk;        // Directory block containing file's entry
  TFS_DIR_ITEM *dir_item;  // Pointer to directory item
  uint32_t size;           // Current file size
  uint32_t first_blk;      // First data block
  uint32_t curr_blk;       // Current block for seek position
  uint32_t curr_pos;       // Current position in file
} TFS_FILEHANDLE;

static TFS_FILEHANDLE handles[TFS_MAX_FDS];
```

### Handle Management

**Opening a file:**
```c
int8_t tfs_open(const char *name) {
  // Search for file
  item = find_file(name, 0);
  
  // Check if file already open
  for (fd = 0, hnd = handles; fd < TFS_MAX_FDS; fd++, hnd++) {
    if (hnd->dir_blk == loaded_dir_blk && 
        hnd->dir_item == item && 
        hnd->usage_count > 0) {
      // Already open, increment reference count
      (hnd->usage_count)++;
      return fd;
    }
  }
  
  // Find free handle
  for (fd = 0, hnd = handles; hnd->usage_count > 0; fd++, hnd++) {
    if (fd == TFS_MAX_FDS) {
      tfs_last_error = TFS_ERR_NO_FREE_FD;
      return -1;
    }
  }
  
  // Initialize handle
  hnd->usage_count = 1;
  hnd->dir_blk = loaded_dir_blk;
  hnd->dir_item = item;
  hnd->size = item->size;
  hnd->first_blk = item->blk;
  init_pos(hnd);  // Set curr_blk and curr_pos
  
  return fd;
}
```

**Key feature:** Multiple opens of same file return same descriptor (reference counting).

### Seek Algorithm

The `seek()` function positions the file handle at a specific offset:

```c
static uint8_t seek(TFS_FILEHANDLE *hnd, uint32_t pos, uint8_t append) {
  // Special case: seeking to 0 or current block invalid
  if (pos == 0 || hnd->curr_blk == 0) {
    init_pos(hnd);  // Start from beginning
  }
  
  // Seek backward if needed
  while (hnd->curr_blk != 0 && hnd->curr_pos > pos) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    hnd->curr_blk = blk_buf.data.prev;
    hnd->curr_pos -= TFS_DATA_LEN;
  }
  
  // Seek forward
  while (hnd->curr_blk != 0 && (hnd->curr_pos + TFS_DATA_LEN) <= pos) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    last_blk = hnd->curr_blk;
    last_pos = hnd->curr_pos;
    hnd->curr_blk = blk_buf.data.next;
    hnd->curr_pos += TFS_DATA_LEN;
  }
  
  // Position found
  if (hnd->curr_blk != 0) {
    drive_read_block(hnd->curr_blk, blk_buf.raw);
    return SEEK_OK;
  }
  
  // Beyond EOF - append if allowed
  if (append) {
    // ... allocate new blocks as needed ...
    return SEEK_APPEND;
  }
  
  return SEEK_EOF;
}
```

### Seek Optimizations

**Bidirectional traversal:** Can seek backward using `prev` pointers.

**Position tracking:** Maintains `curr_pos` to know which block we're in without checking offsets.

**Block caching:** Last block stays in `blk_buf` after seek completes.

**Lazy allocation:** New blocks only allocated when `append == 1`.

### Write with Auto-Extend

The `tfs_write()` function can extend files automatically:

```c
uint32_t tfs_write(int8_t fd, const uint8_t *data, uint32_t len, uint32_t offset) {
  // Seek to position (with append enabled)
  if (seek(hnd, offset, 1) == SEEK_APPEND) {
    append = 1;      // We extended the file
    update_item = 1; // Need to update directory entry
  }
  
  // Write data in blocks
  blk_os = offset - hnd->curr_pos;  // Offset within block
  blk_len = TFS_DATA_LEN - blk_os; // Bytes remaining in block
  
  while (1) {
    // Write to current block
    if (blk_len > len) blk_len = len;
    memcpy(blk_buf.data.data + blk_os, data, blk_len);
    
    // Allocate next block if needed
    if (len > 0 && blk_buf.data.next == 0) {
      blk_buf.data.next = alloc_block();
      append = 1;
    }
    
    drive_write_block(hnd->curr_blk, blk_buf.raw);
    
    // Update file size if we extended it
    if (offset > hnd->size) {
      hnd->size = offset;
      update_item = 1;
    }
    
    // ... move to next block ...
  }
  
  // Update directory if size changed
  if (update_item) {
    update_dir_item(hnd);
  }
}
```

**Key features:**
- Automatically extends file if writing beyond EOF
- Allocates blocks on-demand
- Updates directory entry only once at end
- Handles partial block writes

---

## Code Organization

### File Structure

The `filesys.c` file is organized as follows:

1. **Includes and defines** (lines 1-100)
   - Block structure definitions
   - Helper macros
   - Constants

2. **Static variables** (lines 100-150)
   - Buffers (bitmap, block buffer)
   - State tracking (current directory, loaded blocks)
   - File handles (Extended API)

3. **Internal helpers** (lines 150-400)
   - `load_bitmap()` - Load bitmap block
   - `alloc_block()` - Allocate new block
   - `free_block()` - Free single block
   - `free_file_blocks()` - Free file chain
   - `write_dir_cleanup()` - Optimize directories
   - `find_file()` - Search directory

4. **Public API** (lines 400-1000)
   - `tfs_init()` - Initialize
   - `tfs_format()` - Format device
   - `tfs_get_used()` - Get usage
   - `tfs_read_dir()` - List directory
   - `tfs_change_dir_*()` - Navigate
   - `tfs_create_dir()` - Create directory
   - `tfs_write_file()` / `tfs_read_file()` - Basic I/O
   - `tfs_delete()` / `tfs_rename()` - File management

5. **Extended API** (lines 1000-1537)
   - `tfs_stat()` / `tfs_touch()` - File info
   - `tfs_open()` / `tfs_close()` - Handle management
   - `tfs_trunc()` - Resize file
   - `tfs_write()` / `tfs_read()` - Random access I/O
   - `seek()` - Position within file
   - Helper functions

### Naming Conventions

- **Public functions**: `tfs_*` - User-facing API
- **Static functions**: `lowercase_with_underscores` - Internal helpers
- **Macros**: `TFS_UPPERCASE` - Constants and macros
- **Types**: `TFS_*` - Public structures

### Error Handling Pattern

All functions follow this pattern:

```c
void some_function(args) {
  // Check for device error
  if (tfs_last_error == TFS_ERR_NO_DEV) {
    return;
  }
  
  // Clear error at start
  tfs_last_error = TFS_ERR_OK;
  
  // Select device
  drive_select();
  
  // Do operations...
  // Each operation may set tfs_last_error
  if (tfs_last_error != TFS_ERR_OK) {
    goto out;
  }
  
  // More operations...
  
out:
  // Always deselect device
  drive_deselect();
}
```

**Key points:**
- Check for NO_DEV at function entry
- Clear error at start of operation
- Select device before I/O
- Always deselect device (even on error)
- Use goto for cleanup (single exit point)

---

## Performance Considerations

### Optimization Techniques Used

1. **Bitmap caching** - Avoid repeated bitmap reads
2. **Block reuse** - Single buffer for all block types
3. **Lazy allocation** - Allocate blocks only when needed
4. **Directory cleanup** - Remove empty blocks automatically
5. **Reference counting** - Share file handles when possible
6. **Seek optimization** - Track position to minimize traversal

### Performance Characteristics

| Operation | Best Case | Worst Case | Average |
|-----------|-----------|------------|---------|
| Allocate block | O(1) | O(n bitmaps) | O(1) |
| Free block | O(1) | O(1) + I/O | O(1) |
| Find file | O(1) | O(n items) | O(m items in dir) |
| Sequential read | O(n blocks) | O(n blocks) | O(n blocks) |
| Random read | O(1) | O(n blocks) | O(seek distance) |
| Directory scan | O(n items) | O(n items) | O(n items) |

### Memory Usage

**Fixed overhead:**
- Bitmap buffer: 512 bytes
- Block buffer: 512 bytes
- State variables: ~20 bytes
- **Total: ~1044 bytes**

**Extended API overhead:**
- Per handle: 28 bytes
- Default 32 handles: 896 bytes
- **Total with Extended API: ~1940 bytes**

### Code Size

Approximate code sizes (optimized build):
- Core functionality: 6-7 KB
- Format support: +1-2 KB
- Extended API: +3-4 KB
- **Total (all features): 12-15 KB**

---

## Debugging Tips

### Adding Debug Output

Insert debug output at key points:

```c
#ifdef DEBUG
#define DBG_PRINT(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define DBG_PRINT(fmt, ...)
#endif

// Usage:
DBG_PRINT("Allocating block from bitmap %u\n", loaded_bitmap_blk);
```

### Common Issues

**Buffer confusion:**
- Symptom: Corrupted data or crashes
- Cause: Using `blk_buf` after it's been overwritten
- Solution: Track what's in buffer, reload when needed

**Bitmap cache stale:**
- Symptom: Disk full errors when space exists
- Cause: Bitmap not reloaded after operations
- Solution: Ensure `loaded_bitmap_blk` is updated correctly

**Directory pointer errors:**
- Symptom: Lost files or directory corruption
- Cause: Incorrect prev/next pointer updates
- Solution: Draw state diagrams before modifying chains

### Validation Functions

Add runtime validation (debug builds only):

```c
#ifdef DEBUG
static void validate_bitmap(void) {
  // Check bitmap block is actually a bitmap block
  if ((loaded_bitmap_blk & TFS_BITMAP_BLK_MASK) != 0) {
    printf("ERROR: Invalid bitmap block %u\n", loaded_bitmap_blk);
  }
}

static void validate_handle(int8_t fd) {
  if (fd < 0 || fd >= TFS_MAX_FDS) {
    printf("ERROR: Invalid FD %d\n", fd);
  }
  if (handles[fd].usage_count == 0) {
    printf("ERROR: Handle %d not in use\n", fd);
  }
}
#endif
```
