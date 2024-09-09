# tinyfs

This is a file system for tiny systems. The initial reason to create this project
was the attempt to build a file system that can run on a ZX81 without any
additional processors (e.g. an ATMEGA for FAT32 support).

![ZXSD PCB](https://github.com/sittner/tinyfs/raw/main/zx81/hardware/zxsd.png)

In fact, this was a little bit challenging, because I wanted to use 32k RAM and
32k ROM and due to the architecture of the ZX video system only the lower 16k of
ROM is useable for executable code. 8k of that is already used by the original
OS, so the code for the FS has to fit into the remaining 8k block. Fortunately
the upper 16k is useable to store constant data, so all stuff like that
(i.e. Strings and initializer data) is stored in that area.

## File system features

The main goal was simplicity. So a few features found on file systems like
FAT/ext2 are missing:

* no create/access/modify timestamps
* no file attributes
* no ownership or ACLs
* no caching
* hard to fix structural inconsistencies due to the lack of redundant metadata
* only 512kB block size supported

The pro list shows:

* maximum volume size up to 2TB
* maximum file size up to 4GB
* efficient metadata access
* low code size
* low RAM usage
* static memory management

## Hardware

The hardware is a ZX81 expansion board consisting of 32kB RAM and ROM as well as
an SD card interface. It was important to me to only use hardware (apart from
the SD card itself) that would also have been available in the era of the ZX81.
That's why I deliberately did not use FPGA, CPLD or coprocessors.

[See the ZXSD schematic](https://github.com/sittner/tinyfs/raw/main/zx81/hardware/zxsd.pdf).

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

### Linux

To allow easy access to the file system on the SD card from outside the ZX81
world there is a Linux FUSE port as well. This could easily be build via the
included Makefile. As dependency, only libfuse is required.

You can format a SD card, for example:

    sudo ./mktfs /dev/mmcblk0

To mount the SD card, you could use:

    sudo ./tfs -f -o uid=1000,gid=1000,allow_other /dev/mmcblk0 /mnt

Don't forget to umount after work is done:

    sudo unount /mnt

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

