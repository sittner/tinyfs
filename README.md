# TinyFS

TinyFS is a minimalist filesystem designed for extremely constrained embedded systems. The initial reason to create this project was the attempt to build a filesystem that can run on a ZX81 without any additional processors (e.g. an ATMEGA for FAT32 support).

![ZXSD PCB](https://github.com/sittner/tinyfs/raw/main/zx81/hardware/zxsd.png)

In fact, this was a little bit challenging, because I wanted to use 32k RAM and 32k ROM and due to the architecture of the ZX video system only the lower 16k of ROM is useable for executable code. 8k of that is already used by the original OS, so the code for the FS has to fit into the remaining 8k block. Fortunately the upper 16k is useable to store constant data, so all stuff like that (i.e. strings and initializer data) is stored in that area.

## Quick Start

```c
#include "filesys.h"

int main(void) {
    // Initialize the filesystem
    tfs_init();
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Failed to initialize filesystem\n");
        return 1;
    }
    
    // Write a file
    const char *data = "Hello, TinyFS!";
    tfs_write_file("hello.txt", (uint8_t*)data, strlen(data), 1);
    
    // Read it back
    uint8_t buffer[256];
    uint32_t bytes = tfs_read_file("hello.txt", buffer, sizeof(buffer));
    buffer[bytes] = '\0';
    printf("Read: %s\n", buffer);
    
    return 0;
}
```

See [docs/USAGE_EXAMPLES.md](docs/USAGE_EXAMPLES.md) for more examples.

## Features

TinyFS is designed for extreme simplicity and minimal resource usage, making deliberate trade-offs between features and footprint.

### Capabilities

* **Maximum volume size:** Up to 2TB (terabytes)
* **Maximum file size:** Up to 4GB (gigabytes)
* **Efficient metadata access:** Direct block addressing
* **Low code size:** ~6-15 KB depending on features
* **Low RAM usage:** ~1-3 KB depending on configuration
* **Static memory management:** No dynamic allocation
* **Sequential and random file access:** With Extended API
* **Subdirectory support:** Unlimited nesting depth
* **Portable:** Easy to port to any platform with block storage

### Limitations

To achieve minimal resource usage, the following features are intentionally omitted:

* **No timestamps:** No creation, access, or modification times
* **No file attributes:** No permissions, ownership, or ACLs
* **No caching:** Direct block I/O (simple but slower)
* **No redundancy:** Limited error recovery from corruption
* **Fixed block size:** 512 bytes only (matches SD card sectors)

These trade-offs make TinyFS ideal for extremely constrained systems where FAT32, ext2, or other filesystems won't fit.

## Hardware

The hardware is a ZX81 expansion board consisting of 32kB RAM and ROM as well as
an SD card interface. It was important to me to only use hardware (apart from
the SD card itself) that would also have been available in the era of the ZX81.
That's why I deliberately did not use FPGA, CPLD or coprocessors.

[See the ZXSD schematic](https://github.com/sittner/tinyfs/raw/main/zx81/hardware/zxsd.pdf).

The board contains a memory expansion, because we need some RAM for variables
and buffers and obviously ROM to store the file system code.

The Memory map looks as this:

| Address area    | Mapped device    | Usage                                                          |
|-----------------|------------------|----------------------------------------------------------------|
| 0x0000 - 0x3FFF | ROM (lower 16kB) | 0x0000 - 0x1FFF: Original ROM code (patched with TinyFS hooks) |
|                 |                  | 0x2000 - 0x3FFF: TinyFS code                                   |
| 0x4000 - 0x7FFF | RAM (lower 16kB) | Normal ZX81 RAM (available to the user)                        |
| 0x8000 - 0xBFFF | ROM (upper 16kB) | Constant data for TinyFS                                       |
| 0xC000 - 0xFFFF | RAM (upper 16kB) | 0xC000 - 0xF7FF: Unused (could be used as DFILE e.g. for HRG)  |
|                 |                  | 0xF800 - 0xFFFF: TinyFS variables and buffers                  |

Unfortunately, I've found no easy way to allow RAM in the 0x2000 - 0x3FFF area,
which means that the board will not work with WRX16. The NOP logic of the ZX81
requires that the TinyFS code resides in the lower 32kB area to be executable,
and I've preferred to provide 16kB of RAM.

Other hires systems like WRX1K, Kevin Baker's HIRES16K or HRG-ms seems to work.

Many thanks to Siggi who helped me much in streamlining the memory encoder stuff.

## Supported Platforms

TinyFS has been ported to multiple platforms and can be adapted to any system with block storage.

### Official Ports

* **ZX81** - Z80 with SD card via custom hardware SPI
  - ROM: ~8 KB, RAM: ~1 KB
  - Case-insensitive filenames
  - Sequential access only
  
* **AVR (ATmega328P)** - 8-bit AVR with SD card via hardware SPI
  - Flash: ~10 KB, RAM: ~1 KB
  - Format support
  - Sequential access only
  
* **Linux (FUSE)** - Full-featured desktop implementation
  - File-backed or block device
  - All features enabled
  - Random file access with up to 32 file descriptors

### Custom Platforms

TinyFS can be ported to any platform that provides:
- Block storage with 512-byte sectors (SD/MMC cards, flash, file emulation)
- Approximately 1-3 KB of RAM
- Approximately 6-15 KB of ROM/Flash for code

See [docs/PORTING_GUIDE.md](docs/PORTING_GUIDE.md) for porting instructions.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

* **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Filesystem design and internal structures
  - Overview of block types (bitmap, directory, data)
  - Block size and layout details
  - Memory usage and limitations
  
* **[API_REFERENCE.md](docs/API_REFERENCE.md)** - Complete API documentation
  - All public functions with examples
  - Error codes and handling
  - Basic and Extended API reference
  
* **[CONFIGURATION.md](docs/CONFIGURATION.md)** - Configuration options guide
  - Feature flags (format, extended API, etc.)
  - Platform-specific settings
  - Memory vs. features trade-offs
  
* **[USAGE_EXAMPLES.md](docs/USAGE_EXAMPLES.md)** - Practical code examples
  - Basic file operations
  - Directory navigation
  - Random access I/O (Extended API)
  - Error handling patterns
  
* **[PORTING_GUIDE.md](docs/PORTING_GUIDE.md)** - How to port to new platforms
  - Required interface functions
  - Platform examples (AVR, Linux, ZX81)
  - Testing and troubleshooting
  
* **[INTERNAL_DESIGN.md](docs/INTERNAL_DESIGN.md)** - Implementation details
  - Block buffer management
  - Allocation algorithms
  - Seek optimization
  - Performance characteristics

## Ports

### ZX81

All SD card access is done by LOAD and SAVE commands prefixed by a ':' as
file name:

| Command              | Description                                                     |
|----------------------|-----------------------------------------------------------------|
| LOAD ":?"            | show drive info                                                 |
| LOAD ":*"            | show drive info with used blocks (could be very time-consuming) |
| LOAD ":"             | show current dir                                                |
| LOAD ":/"            | change to root dir                                              |
| LOAD ":<"            | change to parent dir                                            |
| LOAD ":>[DIRNAME]"   | change to DIRNAME                                               |
| LOAD ":[FILENAME]"   | load file FILENAME                                              |
| SAVE ":$"            | format disk                                                     |
| SAVE ":>[DIRNAME]"   | create dir DIRNAME                                              |
| SAVE ":=[OLD]:[NEW]" | rename file [OLD] to [NEW]                                      |
| SAVE ":-[FILENAME]"  | delete file [FILENAME]                                          |
| SAVE ":[FILENAME]"   | save file FILENAME                                              |

Without prefix, LOAD/SAVE acts as normal tape operation.

To build the hex file for the ROM you will need [SDCC](https://sdcc.sourceforge.net/)
version [4.5.0](https://sourceforge.net/projects/sdcc/files/sdcc/4.5.0/sdcc-src-4.5.0.tar.bz2/download).

### Linux

To allow easy access to the file system on the SD card from outside the ZX81
world there is a Linux FUSE port as well. This could easily be build via the
included Makefile. As dependency, only libfuse is required.

You can format a SD card, for example:

    sudo ./mktfs /dev/mmcblk0

To mount the SD card, you could use:

    sudo ./tfs -f -o uid=1000,gid=1000,allow_other /dev/mmcblk0 /mnt

Don't forget to umount after work is done:

    sudo umount /mnt

### AVR

This port currently runs on a ATMEGA328P. It provides a simple CLI accessible
via UART @9600 Baud. The main intention of this port was to start developing
the FS code before the actual zx81 hardware was finished, so it is currently
not tested very well.

## Internal structure

Only three types of disk blocks exists:

* Bitmap blocks
* Directory blocks
* Data blocks

### Bitmap blocks

Bitmap blocks are used to track allocated/free blocks. There is stored no meta
data information inside these block, just a plain bit array for 8 x 512 = 4096
bits. If a block is in use, a '1' on the corresponding location is indicating
this.

The bitmap block itself is always marked as used, so the first bit of the bitmap
block is always set to '1'. The following 2023 Blocks can be uses as directory
or data blocks.

Offset calculation is very simple, since the first bitmap block is located on
the beginning of the storage device (block offset 0) and the subsequent bitmap
blocks will be following every 4096 blocks. So the position of the corresponding
bitmap block for a given data/directory block can be calculated by logical
shift/and operations.

The last used bitmap block with free block available is cached in memory to
speed up allocation for data/directory blocks. The bitmap block is needed to read
only once and every following allocation of further blocks just require an write
operation to keep the mapping data on disk up to date. 

### Directory blocks

Directory block are the most complex structures of this file system. They are
used to organize files and subdirectories and store the names of these items.

To allow a virtually unlimited count of items per directory layer and simplify
the process of allocation/freeing directory blocks, they are built as double
linked list. The member *parent* always pointed to the corresponding parent
directory block. A value of '0' is indicating that we are on a root directory
block. The first root directory block on disk could be found on block offset 1.

    typedef struct {
      uint32_t prev;
      uint32_t next;
      uint32_t parent;
      TFS_DIR_ITEM items[];
    } _PACKED TFS_DIR_BLK;

There are 20 items per directory block. An item could be one of the type *free*,
*dir* or *file*. The member *blk* pointed to either the corresponding sub
directory block or to the first data block of the corresponding file. The member
*size* holds the size of the entire file (in case of a subdirectory item it is
set to '0').
    
    #define TFS_NAME_LEN 16

    typedef struct {
      uint32_t blk;
      uint32_t size;
      uint8_t type;
      char name[TFS_NAME_LEN];
    } _PACKED TFS_DIR_ITEM;
    
    #define TFS_DIR_ITEM_FREE 0
    #define TFS_DIR_ITEM_DIR  1
    #define TFS_DIR_ITEM_FILE 2

### Data blocks

These blocks contain the actual file data. They are chained as double linked
list and holding 504 bytes of user data each.

    typedef struct {
      uint32_t prev;
      uint32_t next;
      uint8_t data[];
    } _PACKED TFS_DATA_BLK;

