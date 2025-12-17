# TinyFS Architecture

## Overview

TinyFS is a minimalist filesystem designed for tiny embedded systems with severe memory and code size constraints. It was originally developed to run on a ZX81 (with only 8KB of available ROM space for filesystem code) without requiring additional processors or complex hardware.

### Design Goals

- **Simplicity**: Easy to understand and implement
- **Low Code Size**: Fits in 8KB of ROM on constrained systems like the ZX81
- **Low RAM Usage**: Minimal static buffers (approximately 1.5KB total)
- **Static Memory Management**: No dynamic memory allocation
- **Portability**: Can be ported to any platform with block storage

### Design Trade-offs

To achieve these goals, TinyFS deliberately omits features found in more complex filesystems:

- **No Timestamps**: No creation, access, or modification times
- **No File Attributes/Permissions**: No file permissions or ACL system
- **No Caching**: Direct block I/O without caching layer
- **No Redundant Metadata**: Harder to recover from filesystem corruption
- **Fixed Block Size**: 512 bytes only (no configurability)

## Block Structure

TinyFS uses a simple, fixed-size block architecture. All blocks are exactly 512 bytes (`TFS_BLOCKSIZE`), which matches standard sector sizes for SD/MMC cards and simplifies the implementation.

### Block Types

There are only three types of blocks:

1. **Bitmap Blocks**: Track allocated/free blocks
2. **Directory Blocks**: Store directory entries
3. **Data Blocks**: Store file data

### Block Size

The block size is fixed at **512 bytes**, defined as:

```c
#define TFS_BLOCKSIZE_WIDTH 9
#define TFS_BLOCKSIZE       (1 << TFS_BLOCKSIZE_WIDTH)  // 512 bytes
```

This size is:
- Standard for SD/MMC cards (matches physical sector size)
- Small enough for embedded systems with limited RAM
- Large enough to avoid excessive overhead

## Bitmap Management

### Bitmap Block Structure

Bitmap blocks track which blocks are allocated (in use) or free. Each bit in the bitmap represents one block:
- **Bit = 1**: Block is allocated
- **Bit = 0**: Block is free

Since each bitmap block is 512 bytes = 4096 bits, each bitmap block can track **4096 blocks** (512 × 8).

```
Bitmap Block (512 bytes):
+--+--+--+--+--+--+--+--+
|  Each byte = 8 bits   |  Each bit represents one block
|  representing 8 blks  |  0 = free, 1 = allocated
+--+--+--+--+--+--+--+--+
```

### Bitmap Block Placement

Bitmap blocks are placed at regular intervals across the storage device:
- First bitmap block: Block 0
- Next bitmap block: Block 4096
- Next bitmap block: Block 8192
- And so on...

This pattern is calculated as:
```c
#define TFS_BITMAP_BLK_COUNT  (TFS_BLOCKSIZE << 3)      // 4096
#define TFS_BITMAP_BLK_MASK   (TFS_BITMAP_BLK_COUNT - 1) // 0x0FFF
```

To find the bitmap block for any given block number:
```c
bitmap_block = block_number & ~TFS_BITMAP_BLK_MASK;  // Round down to multiple of 4096
```

### Allocation Algorithm

The allocation algorithm uses a "last known good" approach to minimize disk reads:

1. Start from the currently loaded bitmap block
2. Search for a free bit (0) in the bitmap
3. If found:
   - Set the bit to 1 (mark as allocated)
   - Write the updated bitmap block
   - Return the block number
4. If not found:
   - Move to the next bitmap block (wrapping around at end of disk)
   - If we've checked all bitmap blocks, disk is full
   - Otherwise, repeat from step 2

The `loaded_bitmap_blk` variable caches the current bitmap block to avoid redundant reads.

### Maximum Volume Size

With 32-bit block numbers and 512-byte blocks:
- Maximum blocks: 2^32 = 4,294,967,296
- Maximum size: 4,294,967,296 × 512 = **2 TB** (terabytes)

## Directory Structure

### Root Directory

The root directory is always located at **block 1**. This is a fixed location that never changes.

```
Block 0: First bitmap block
Block 1: Root directory (first block)
Block 2+: Other blocks (data, directories, more bitmap blocks)
```

### Directory Block Structure

Directory blocks are organized as a doubly-linked list to support an unlimited number of entries per directory:

```c
typedef struct {
  uint32_t prev;                // Previous directory block (0 if first)
  uint32_t next;                // Next directory block (0 if last)
  uint32_t parent;              // Parent directory block (0 if root)
  TFS_DIR_ITEM items[];         // Array of directory items
} TFS_DIR_BLK;
```

**Layout visualization:**
```
+----------------+
| prev (4 bytes) |  -> Previous block in chain
+----------------+
| next (4 bytes) |  -> Next block in chain
+----------------+
| parent (4 b)   |  -> Parent directory (0 for root)
+----------------+
| item[0]        |  \
+----------------+   |
| item[1]        |   |
+----------------+   |-- TFS_DIR_BLK_ITEMS entries
| ...            |   |   (20 items per block)
+----------------+   |
| item[19]       |  /
+----------------+
```

### Directory Items

Each directory block contains **20 directory items** (`TFS_DIR_BLK_ITEMS`):

```c
#define TFS_DIR_BLK_ITEMS ((TFS_BLOCKSIZE - sizeof(TFS_DIR_BLK)) / sizeof(TFS_DIR_ITEM))
// Result: (512 - 12) / 25 = 20 items
```

Each item has this structure:

```c
#define TFS_NAME_LEN 16

typedef struct {
  uint32_t blk;                  // Block number (directory or first data block)
  uint32_t size;                 // File size (0 for directories)
  uint8_t type;                  // TFS_DIR_ITEM_FREE, _DIR, or _FILE
  char name[TFS_NAME_LEN];       // Name (16 characters max, NOT null-terminated if full)
} TFS_DIR_ITEM;

#define TFS_DIR_ITEM_FREE 0
#define TFS_DIR_ITEM_DIR  1
#define TFS_DIR_ITEM_FILE 2
```

**Item layout (25 bytes per item):**
```
+----------------+
| blk (4 bytes)  |  -> First data block (file) or subdirectory block
+----------------+
| size (4 bytes) |  -> File size in bytes (0 for directories)
+----------------+
| type (1 byte)  |  -> 0=free, 1=dir, 2=file
+----------------+
| name (16 b)    |  -> Filename (may not be null-terminated)
+----------------+
```

### Directory Navigation

- **Current Directory**: Tracked in `current_dir_blk` variable
- **Change to Root**: Set `current_dir_blk = TFS_ROOT_DIR_BLK` (block 1)
- **Change to Parent**: Read current directory block, get `parent` field
- **Change to Subdirectory**: Search for directory item with matching name, get `blk` field

### Directory Growth

When a directory needs more than 20 entries:
1. Allocate a new directory block
2. Link it to the previous block (update `next` and `prev` pointers)
3. Set the `parent` pointer to match the parent directory
4. Initialize all items as `TFS_DIR_ITEM_FREE`

### Directory Cleanup Optimization

When a directory block becomes completely empty (all items are FREE):
- If it's the only block: Keep it
- If it's in a chain: Remove it from the chain and free the block
- This prevents wasted space from deleted files

## File Storage

### Data Block Structure

Files are stored as doubly-linked lists of data blocks:

```c
typedef struct {
  uint32_t prev;                 // Previous data block (0 if first)
  uint32_t next;                 // Next data block (0 if last)
  uint8_t data[];                // User data (504 bytes)
} TFS_DATA_BLK;

#define TFS_DATA_LEN (TFS_BLOCKSIZE - sizeof(TFS_DATA_BLK))  // 504 bytes
```

**Layout visualization:**
```
+----------------+
| prev (4 bytes) |  -> Previous data block
+----------------+
| next (4 bytes) |  -> Next data block
+----------------+
| data (504 b)   |  -> Actual file data
|                |
|   ...          |
+----------------+
```

### Maximum File Size

With 32-bit size field:
- Maximum file size: 2^32 - 1 = **4,294,967,295 bytes** (~4 GB)

### File Storage Efficiency

- Overhead: 8 bytes per block (prev + next pointers)
- Usable data: 504 bytes per block
- Efficiency: 504/512 = **98.4%**

### File Operations

**Writing a file:**
1. Find or create directory item
2. Allocate first data block
3. Fill data blocks in sequence, allocating new blocks as needed
4. Update directory item with first block number and total size

**Reading a file:**
1. Find directory item
2. Follow the chain of data blocks from first to last
3. Copy data from each block
4. Stop when size bytes have been read

**Deleting a file:**
1. Find directory item
2. Follow the chain of data blocks, freeing each one
3. Mark directory item as FREE
4. Optimize directory (remove empty blocks if possible)

## Memory Layout

TinyFS uses static memory allocation exclusively. No dynamic memory allocation (malloc/free) is used.

### Static Buffers

```c
static uint8_t bitmap_blk[TFS_BLOCKSIZE];        // 512 bytes - Current bitmap block
static TFS_BLK_BUFFER blk_buf;                   // 512 bytes - General purpose block buffer
static uint32_t loaded_bitmap_blk;               // 4 bytes   - Currently loaded bitmap block #
static uint32_t current_dir_blk;                 // 4 bytes   - Current directory block #
static uint32_t loaded_dir_blk;                  // 4 bytes   - Currently loaded directory block #
static uint32_t last_bitmap_blk;                 // 4 bytes   - Last bitmap block on disk
static uint16_t last_bitmap_len;                 // 2 bytes   - Bits used in last bitmap block
```

The `blk_buf` is a union that can be interpreted as different block types:

```c
typedef union {
  uint8_t raw[TFS_BLOCKSIZE];    // Raw bytes
  TFS_DIR_BLK dir;                // Directory block
  TFS_DATA_BLK data;              // Data block
} TFS_BLK_BUFFER;
```

### Extended API Additional Memory

When `TFS_EXTENDED_API` is enabled, file handles are tracked:

```c
typedef struct {
  uint8_t usage_count;     // Reference count (0 = unused)
  uint32_t dir_blk;        // Directory block containing this file's entry
  TFS_DIR_ITEM *dir_item;  // Pointer to directory item
  uint32_t size;           // Current file size
  uint32_t first_blk;      // First data block
  uint32_t curr_blk;       // Current block for seek position
  uint32_t curr_pos;       // Current position in file
} TFS_FILEHANDLE;

static TFS_FILEHANDLE handles[TFS_MAX_FDS];  // Default: 32 handles on Linux
```

### Total Static Memory Usage

**Minimal configuration (without extended API):**
- Bitmap buffer: 512 bytes
- Block buffer: 512 bytes
- State variables: ~20 bytes
- **Total: ~1,044 bytes**

**With extended API (32 file descriptors):**
- Minimal: 1,044 bytes
- File handles: 32 × 28 = 896 bytes
- **Total: ~1,940 bytes**

## Limitations

### Fixed Limitations

These are inherent to the design:

1. **No Timestamps**: Files have no creation, modification, or access times
2. **No File Attributes**: No permissions, owner, or access control
3. **No Caching**: Every operation performs disk I/O
4. **Fixed Block Size**: Always 512 bytes (cannot be configured)
5. **No Fragmentation Handling**: Files can become fragmented over time
6. **Limited Error Recovery**: No redundant metadata or journaling

### Configurable Limitations

These depend on configuration and platform:

1. **Maximum Filename Length**: 16 characters (TFS_NAME_LEN)
2. **Directory Entries Per Block**: 20 items
3. **File Descriptors**: Platform-dependent (default 32 on Linux)

### Performance Characteristics

- **Sequential Access**: Excellent (minimal overhead)
- **Random Access**: Good with Extended API (bidirectional seek)
- **Directory Listing**: Linear scan of directory blocks
- **Allocation**: Best-fit from currently loaded bitmap
- **Deletion**: Requires traversing entire file to free blocks

## Platform Requirements

### Required Functions (Implemented by User)

```c
void drive_init(void);                           // Initialize storage hardware
void drive_select(void);                         // Select/enable device
void drive_deselect(void);                       // Deselect/disable device
void drive_read_block(uint32_t blkno, uint8_t *data);   // Read 512-byte block
void drive_write_block(uint32_t blkno, const uint8_t *data); // Write 512-byte block
```

### Required Information (Set by User)

```c
TFS_DRIVE_INFO tfs_drive_info;  // Must be populated in drive_init()
uint8_t tfs_last_error;          // Set by drive functions on error
```

### Minimum System Requirements

- **RAM**: ~1 KB for filesystem (more with Extended API)
- **ROM/Flash**: ~8 KB for filesystem code
- **Storage**: Block device with 512-byte sectors
- **Compiler**: C99 or later (uses stdint.h)

## Comparison with Other Filesystems

| Feature | TinyFS | FAT32 | ext2 | littlefs |
|---------|--------|-------|------|----------|
| Code Size | ~8 KB | ~50+ KB | ~100+ KB | ~15 KB |
| RAM Usage | ~1 KB | ~10+ KB | ~20+ KB | ~5 KB |
| Max File Size | 4 GB | 4 GB | 2 TB | 2 GB |
| Max Volume | 2 TB | 2 TB | 32 TB | 2 GB |
| Timestamps | No | Yes | Yes | No |
| Permissions | No | Limited | Full | No |
| Wear Leveling | No | No | No | Yes |
| Power-loss Safety | No | Limited | Journal | Yes |

TinyFS trades features and robustness for minimal resource usage, making it ideal for extremely constrained systems where other filesystems won't fit.
