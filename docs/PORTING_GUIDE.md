# TinyFS Porting Guide

This guide explains how to port TinyFS to a new platform or hardware configuration.

## Table of Contents

- [Overview](#overview)
- [Required Steps](#required-steps)
- [Drive Interface Implementation](#drive-interface-implementation)
- [Platform Examples](#platform-examples)
- [Testing Your Port](#testing-your-port)
- [Troubleshooting](#troubleshooting)

---

## Overview

Porting TinyFS to a new platform involves:

1. Creating a platform-specific `filesys_conf.h` configuration file
2. Implementing the drive interface functions
3. Setting up the build system for your platform
4. Testing the implementation

The core filesystem code (`filesys.c` and `filesys.h`) is platform-independent and should not need modification.

---

## Required Steps

### Step 1: Create `filesys_conf.h`

Create a configuration header file for your platform. This file controls which features are enabled.

**Minimal template:**

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

// Feature configuration
#define TFS_ENABLE_FORMAT          // Enable if you need format capability
#undef TFS_EXTENDED_API            // Enable if you need random access

// Platform-specific configurations
// Add any platform-specific macros or includes here

#endif
```

See [CONFIGURATION.md](CONFIGURATION.md) for detailed information about all configuration options.

### Step 2: Implement Drive Interface Functions

Implement these five required functions for your storage hardware:

```c
void drive_init(void);
void drive_select(void);
void drive_deselect(void);
void drive_read_block(uint32_t blkno, uint8_t *data);
void drive_write_block(uint32_t blkno, const uint8_t *data);
```

### Step 3: Populate Drive Information

Your `drive_init()` function must populate the `tfs_drive_info` structure:

```c
extern TFS_DRIVE_INFO tfs_drive_info;

// In your drive_init():
tfs_drive_info.type = DRIVE_TYPE_SDHC;
tfs_drive_info.blk_count = /* total number of 512-byte blocks */;
strcpy(tfs_drive_info.model, "Your Device");
strcpy(tfs_drive_info.serno, "12345");
```

### Step 4: Set Error Codes

All drive functions must set `tfs_last_error`:

```c
extern uint8_t tfs_last_error;

// Set to TFS_ERR_OK on success
// Set to TFS_ERR_NO_DEV if no device detected
// Set to TFS_ERR_IO on communication errors
```

---

## Drive Interface Implementation

### `drive_init()`

Initialize the storage hardware and detect the device.

**Responsibilities:**
- Initialize hardware interfaces (SPI, GPIO, etc.)
- Detect and initialize the storage device
- Read device information (capacity, model, etc.)
- Populate `tfs_drive_info` structure
- Set `tfs_last_error` appropriately

**Example for SD card over SPI:**

```c
void drive_init(void) {
    uint8_t card_type;
    uint32_t capacity;
    
    // Initialize SPI hardware
    spi_init();
    
    // Initialize MMC/SD card
    card_type = mmc_init();
    if (card_type == 0) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    // Get card capacity
    capacity = mmc_get_capacity();
    if (capacity == 0) {
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    // Populate drive info
    tfs_drive_info.type = card_type;
    tfs_drive_info.blk_count = capacity;
    
    // Optionally read CID for model/serial
    mmc_read_cid(tfs_drive_info.model, tfs_drive_info.serno);
    
    tfs_last_error = TFS_ERR_OK;
}
```

**Example for emulated storage (file-backed):**

```c
#include <stdio.h>
#include <sys/stat.h>

static FILE *disk_file = NULL;

void drive_init(void) {
    struct stat st;
    
    // Open disk image file
    disk_file = fopen("disk.img", "r+b");
    if (disk_file == NULL) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    // Get file size
    if (fstat(fileno(disk_file), &st) != 0) {
        fclose(disk_file);
        disk_file = NULL;
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    // Populate drive info
    tfs_drive_info.type = DRIVE_TYPE_EMU;
    tfs_drive_info.blk_count = st.st_size / 512;
    strcpy(tfs_drive_info.model, "Emulated Disk");
    strcpy(tfs_drive_info.serno, "EMU001");
    
    tfs_last_error = TFS_ERR_OK;
}
```

---

### `drive_select()` and `drive_deselect()`

Enable and disable the storage device.

**For SPI-based devices:**

```c
// Assuming CS (Chip Select) is on GPIO pin
#define SD_CS_PORT  PORTB
#define SD_CS_DDR   DDRB
#define SD_CS_PIN   PB2

void drive_select(void) {
    // Pull CS low to select device
    SD_CS_PORT &= ~(1 << SD_CS_PIN);
}

void drive_deselect(void) {
    // Pull CS high to deselect device
    SD_CS_PORT |= (1 << SD_CS_PIN);
}
```

**For direct attached devices:**

```c
// If the device is always active, these can be empty
void drive_select(void) {
    // Nothing to do
}

void drive_deselect(void) {
    // Nothing to do
}
```

**For devices with enable pins:**

```c
void drive_select(void) {
    // Enable power or chip enable
    DEVICE_ENABLE_PORT |= DEVICE_ENABLE_PIN;
    // Wait for device to stabilize
    delay_us(10);
}

void drive_deselect(void) {
    // Disable device
    DEVICE_ENABLE_PORT &= ~DEVICE_ENABLE_PIN;
}
```

---

### `drive_read_block()`

Read a single 512-byte block from the device.

**For SD card over SPI:**

```c
void drive_read_block(uint32_t blkno, uint8_t *data) {
    if (mmc_read_block(blkno, data)) {
        tfs_last_error = TFS_ERR_OK;
    } else {
        tfs_last_error = TFS_ERR_IO;
    }
}
```

**For file-backed emulation:**

```c
void drive_read_block(uint32_t blkno, uint8_t *data) {
    if (disk_file == NULL) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    // Seek to block position
    if (fseek(disk_file, blkno * 512, SEEK_SET) != 0) {
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    // Read block
    if (fread(data, 512, 1, disk_file) != 1) {
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    tfs_last_error = TFS_ERR_OK;
}
```

**Important considerations:**
- Must read exactly 512 bytes
- Must handle block addressing correctly (some cards use byte address, others use block address)
- Must set `tfs_last_error` appropriately
- Should handle timeouts and errors gracefully

---

### `drive_write_block()`

Write a single 512-byte block to the device.

**For SD card over SPI:**

```c
void drive_write_block(uint32_t blkno, const uint8_t *data) {
    if (mmc_write_block(blkno, data)) {
        tfs_last_error = TFS_ERR_OK;
    } else {
        tfs_last_error = TFS_ERR_IO;
    }
}
```

**For file-backed emulation:**

```c
void drive_write_block(uint32_t blkno, const uint8_t *data) {
    if (disk_file == NULL) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    // Seek to block position
    if (fseek(disk_file, blkno * 512, SEEK_SET) != 0) {
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    // Write block
    if (fwrite(data, 512, 1, disk_file) != 1) {
        tfs_last_error = TFS_ERR_IO;
        return;
    }
    
    // Flush to ensure write completes
    fflush(disk_file);
    
    tfs_last_error = TFS_ERR_OK;
}
```

**Important considerations:**
- Must write exactly 512 bytes
- Must wait for write to complete before returning
- Must handle write protection
- Must set `tfs_last_error` appropriately

---

## Platform Examples

### Example 1: AVR with SD Card

**Files:**
- `avr/filesys_conf.h` - Configuration
- `avr/spi.c` - SPI driver
- `avr/main.c` - Main program
- `mmc.c` - MMC/SD card driver (shared)

**Configuration (`avr/filesys_conf.h`):**

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#define TFS_ENABLE_FORMAT
#undef TFS_EXTENDED_API

#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif
```

**SPI Driver (`avr/spi.c`):**

```c
#include <avr/io.h>

void spi_init(void) {
    // Set MOSI, SCK, SS as output
    DDRB |= (1 << PB3) | (1 << PB5) | (1 << PB2);
    // Enable SPI, Master mode, clock/16
    SPCR = (1 << SPE) | (1 << MSTR) | (1 << SPR0);
}

uint8_t spi_transfer_byte(uint8_t data) {
    SPDR = data;
    while (!(SPSR & (1 << SPIF)));
    return SPDR;
}
```

**Drive Interface (`avr/main.c`):**

```c
#include "../filesys.h"
#include "../mmc.h"

void drive_init(void) {
    spi_init();
    mmc_card_init();  // From mmc.c
}

void drive_select(void) {
    PORTB &= ~(1 << PB2);  // CS low
}

void drive_deselect(void) {
    PORTB |= (1 << PB2);  // CS high
}

void drive_read_block(uint32_t blkno, uint8_t *data) {
    if (mmc_read_single_block(blkno, data)) {
        tfs_last_error = TFS_ERR_OK;
    } else {
        tfs_last_error = TFS_ERR_IO;
    }
}

void drive_write_block(uint32_t blkno, const uint8_t *data) {
    if (mmc_write_single_block(blkno, data)) {
        tfs_last_error = TFS_ERR_OK;
    } else {
        tfs_last_error = TFS_ERR_IO;
    }
}
```

---

### Example 2: Linux (File-Backed)

**Files:**
- `linux/filesys_conf.h` - Configuration
- `linux/drive.c` - Drive interface
- `linux/tfs_fuse.c` - FUSE integration

**Configuration (`linux/filesys_conf.h`):**

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#include <fuse.h>

#define TFS_ENABLE_FORMAT
#define TFS_FORMAT_STATE_CALLBACK
#define TFS_EXTENDED_API
#define TFS_MAX_FDS 32

typedef struct {
    void *buffer;
    fuse_fill_dir_t filler;
} TFS_READDIR_FILLER;

#define TFS_READ_DIR_USERDATA const TFS_READDIR_FILLER *

#endif
```

**Drive Interface (`linux/drive.c`):**

```c
#include "../filesys.h"
#include <stdio.h>
#include <sys/stat.h>
#include <string.h>

static FILE *disk_file = NULL;
static char *disk_path = NULL;

void drive_set_path(const char *path) {
    disk_path = strdup(path);
}

void drive_init(void) {
    struct stat st;
    
    if (disk_path == NULL) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    disk_file = fopen(disk_path, "r+b");
    if (disk_file == NULL) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    fstat(fileno(disk_file), &st);
    
    tfs_drive_info.type = DRIVE_TYPE_EMU;
    tfs_drive_info.blk_count = st.st_size / 512;
    strcpy(tfs_drive_info.model, "Linux File");
    strcpy(tfs_drive_info.serno, "FILE001");
    
    tfs_last_error = TFS_ERR_OK;
}

void drive_select(void) {
    // Nothing to do
}

void drive_deselect(void) {
    // Nothing to do
}

void drive_read_block(uint32_t blkno, uint8_t *data) {
    if (fseek(disk_file, blkno * 512, SEEK_SET) != 0 ||
        fread(data, 512, 1, disk_file) != 1) {
        tfs_last_error = TFS_ERR_IO;
    } else {
        tfs_last_error = TFS_ERR_OK;
    }
}

void drive_write_block(uint32_t blkno, const uint8_t *data) {
    if (fseek(disk_file, blkno * 512, SEEK_SET) != 0 ||
        fwrite(data, 512, 1, disk_file) != 1) {
        tfs_last_error = TFS_ERR_IO;
    } else {
        fflush(disk_file);
        tfs_last_error = TFS_ERR_OK;
    }
}
```

---

### Example 3: ZX81 (Z80 with SD Card)

**Files:**
- `zx81/filesys_conf.h` - Configuration
- `zx81/spi.c` - Bit-banged SPI
- `mmc.c` - MMC/SD card driver (shared)

**Configuration (`zx81/filesys_conf.h`):**

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

// No format support (done externally to save space)
#undef TFS_ENABLE_FORMAT

// No extended API (RAM constrained)
#undef TFS_EXTENDED_API

// Case-insensitive filenames
#define TFS_FILENAME_CMP(ref, cmp) filename_cmp(ref, cmp)
uint8_t filename_cmp(const char *ref, const char *cmp);

// SPI macros
#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif
```

**Key differences:**
- Case-insensitive filename comparison (ZX81 character set)
- No formatting (save ROM space)
- No extended API (save RAM)
- Bit-banged SPI (no hardware SPI on Z80)

---

## Testing Your Port

### Step 1: Compilation Test

Ensure the code compiles without errors:

```bash
# Replace with your compiler
gcc -c filesys.c -I. -o filesys.o
```

### Step 2: Initialization Test

Test basic initialization:

```c
int main(void) {
    tfs_init();
    
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Init failed: %d\n", tfs_last_error);
        return 1;
    }
    
    printf("Device initialized\n");
    printf("Type: %d\n", tfs_drive_info.type);
    printf("Blocks: %u\n", tfs_drive_info.blk_count);
    
    return 0;
}
```

### Step 3: Format Test

If formatting is enabled:

```c
void test_format(void) {
    printf("Formatting...\n");
    tfs_format();
    
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Format failed: %d\n", tfs_last_error);
        return;
    }
    
    printf("Format successful\n");
}
```

### Step 4: Read/Write Test

Test basic file operations:

```c
void test_read_write(void) {
    const char *test_data = "Hello, TinyFS!";
    uint8_t buffer[100];
    
    // Write file
    tfs_write_file("test.txt", (uint8_t*)test_data, strlen(test_data), 1);
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Write failed: %d\n", tfs_last_error);
        return;
    }
    
    // Read file back
    uint32_t bytes = tfs_read_file("test.txt", buffer, sizeof(buffer));
    buffer[bytes] = '\0';
    
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Read failed: %d\n", tfs_last_error);
        return;
    }
    
    // Compare
    if (strcmp((char*)buffer, test_data) == 0) {
        printf("Read/Write test PASSED\n");
    } else {
        printf("Read/Write test FAILED\n");
    }
}
```

### Step 5: Stress Test

Test with larger files and multiple operations:

```c
void stress_test(void) {
    uint8_t buffer[512];
    int i;
    
    // Write multiple files
    for (i = 0; i < 10; i++) {
        char name[20];
        sprintf(name, "file%d.dat", i);
        
        // Fill buffer with pattern
        memset(buffer, i, sizeof(buffer));
        
        tfs_write_file(name, buffer, sizeof(buffer), 1);
        if (tfs_last_error != TFS_ERR_OK) {
            printf("Write %d failed: %d\n", i, tfs_last_error);
            return;
        }
    }
    
    // Read and verify
    for (i = 0; i < 10; i++) {
        char name[20];
        sprintf(name, "file%d.dat", i);
        
        memset(buffer, 0, sizeof(buffer));
        tfs_read_file(name, buffer, sizeof(buffer));
        
        if (tfs_last_error != TFS_ERR_OK) {
            printf("Read %d failed: %d\n", i, tfs_last_error);
            return;
        }
        
        // Verify pattern
        int j;
        for (j = 0; j < 512; j++) {
            if (buffer[j] != (uint8_t)i) {
                printf("Verify %d failed at byte %d\n", i, j);
                return;
            }
        }
    }
    
    printf("Stress test PASSED\n");
}
```

---

## Troubleshooting

### Device Not Detected

**Symptom:** `tfs_init()` sets `tfs_last_error = TFS_ERR_NO_DEV`

**Possible causes:**
1. Hardware not connected or powered
2. SPI/communication interface not initialized
3. Wrong GPIO pins configured
4. Card initialization sequence incorrect

**Debug steps:**
1. Check hardware connections
2. Verify power supply to card
3. Check SPI clock and data lines with oscilloscope
4. Add debug output to `drive_init()` to see where it fails

### I/O Errors

**Symptom:** `tfs_last_error = TFS_ERR_IO` during read/write

**Possible causes:**
1. Block addressing wrong (byte vs. block address)
2. Timeout in communication
3. Card removed or failed
4. Buffer overflow or corruption

**Debug steps:**
1. Verify block address calculation
2. Check read/write timing requirements
3. Add timeouts to prevent infinite loops
4. Verify 512-byte buffer alignment

### Corrupted Data

**Symptom:** Data read back doesn't match what was written

**Possible causes:**
1. Byte order issues (endianness)
2. Buffer overrun
3. Incomplete writes
4. Caching issues

**Debug steps:**
1. Write known pattern and verify
2. Check if write completes before read
3. Flush buffers after writes
4. Verify no buffer sharing issues

### Out of Memory / Stack Overflow

**Symptom:** System crashes or behaves erratically

**Possible causes:**
1. Stack too small for 512-byte buffers
2. Recursive functions on constrained systems
3. Too many file descriptors configured

**Solutions:**
1. Increase stack size
2. Reduce `TFS_MAX_FDS` if using Extended API
3. Check static buffer allocation
4. Avoid large local variables in functions

### Performance Issues

**Symptom:** Operations are very slow

**Possible causes:**
1. SPI clock too slow
2. Excessive bitmap block reads
3. Fragmented files
4. Debug output slowing down operations

**Solutions:**
1. Increase SPI clock frequency (within card limits)
2. Ensure bitmap caching is working
3. Format device to defragment
4. Remove debug output from hot paths

---

## Additional Resources

- See [ARCHITECTURE.md](ARCHITECTURE.md) for filesystem internals
- See [API_REFERENCE.md](API_REFERENCE.md) for function details
- See [CONFIGURATION.md](CONFIGURATION.md) for configuration options
- Check existing platform implementations in `avr/`, `linux/`, and `zx81/` directories

---

## Checklist for New Port

- [ ] Created `filesys_conf.h` with appropriate feature flags
- [ ] Implemented `drive_init()`
- [ ] Implemented `drive_select()`
- [ ] Implemented `drive_deselect()`
- [ ] Implemented `drive_read_block()`
- [ ] Implemented `drive_write_block()`
- [ ] Populated `tfs_drive_info` structure
- [ ] Set `tfs_last_error` in all drive functions
- [ ] Code compiles without errors
- [ ] Initialization test passes
- [ ] Format test passes (if enabled)
- [ ] Read/write test passes
- [ ] Stress test passes
- [ ] Performance is acceptable
- [ ] Documentation updated with platform-specific notes
