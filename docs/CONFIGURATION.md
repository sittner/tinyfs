# TinyFS Configuration Guide

TinyFS is configured through the `filesys_conf.h` header file, which must be created for each platform. This file controls which features are enabled and how the filesystem behaves.

## Configuration File Location

The `filesys_conf.h` file must be in the include path when compiling `filesys.c`. Typically, each platform has its own configuration file in its directory:

- Linux: `linux/filesys_conf.h`
- AVR: `avr/filesys_conf.h`
- ZX81: `zx81/filesys_conf.h`

## Configuration Options

### `TFS_ENABLE_FORMAT`

Enable formatting functionality.

```c
#define TFS_ENABLE_FORMAT
```

**Effect:**
- Enables the `tfs_format()` function
- Adds approximately 1-2 KB to code size

**When to use:**
- Enable if you need to format devices from within your application
- Disable for read-only applications or where formatting is done externally

**Example:**
```c
// Enable formatting
#define TFS_ENABLE_FORMAT

// Or disable formatting
#undef TFS_ENABLE_FORMAT
```

---

### `TFS_FORMAT_STATE_CALLBACK`

Enable format progress callbacks.

```c
#define TFS_FORMAT_STATE_CALLBACK
```

**Effect:**
- Enables `tfs_format_state()` and `tfs_format_progress()` callbacks during formatting
- Requires `TFS_ENABLE_FORMAT` to be defined
- Adds minimal code size (~100-200 bytes)

**When to use:**
- Enable if you want to display format progress to the user
- Disable for minimal code size or headless operation

**User must implement:**
```c
void tfs_format_state(uint8_t state);
void tfs_format_progress(uint32_t pos, uint32_t max);
```

---

### `TFS_EXTENDED_API`

Enable extended file API with file descriptors.

```c
#define TFS_EXTENDED_API
```

**Effect:**
- Enables: `tfs_stat()`, `tfs_touch()`, `tfs_open()`, `tfs_close()`, `tfs_trunc()`, `tfs_write()`, `tfs_read()`
- Adds file handle management
- Adds approximately 3-4 KB to code size
- Increases RAM usage by `TFS_MAX_FDS × sizeof(TFS_FILEHANDLE)` (typically ~28 bytes per handle)

**When to use:**
- Enable for applications needing random file access
- Enable for applications that modify files in-place
- Disable for minimal systems that only need sequential file access

**Example:**
```c
// Enable extended API
#define TFS_EXTENDED_API

// Or disable extended API
#undef TFS_EXTENDED_API
```

---

### `TFS_MAX_FDS`

Maximum number of file descriptors (Extended API only).

```c
#define TFS_MAX_FDS 32
```

**Effect:**
- Sets the maximum number of files that can be open simultaneously
- Each file descriptor uses approximately 28 bytes of RAM
- Only relevant when `TFS_EXTENDED_API` is defined

**Default values:**
- Linux: 32 (plenty of RAM available)
- AVR: Not used (Extended API disabled)
- ZX81: Not used (Extended API disabled)

**When to configure:**
- Increase if you need more simultaneous open files
- Decrease to save RAM on constrained systems
- Typical values: 4-8 for embedded systems, 16-32 for larger systems

**Example:**
```c
#define TFS_EXTENDED_API
#define TFS_MAX_FDS 8  // Maximum 8 open files
```

---

### `TFS_READ_DIR_USERDATA`

Type for user data passed to directory handler.

```c
#define TFS_READ_DIR_USERDATA const TFS_READDIR_FILLER *
```

**Effect:**
- Changes the signature of `tfs_read_dir()` and `tfs_dir_handler()` to include user data parameter
- No code size impact
- Useful for passing context to the directory handler

**When to use:**
- Enable when you need to pass data to the directory handler callback
- Leave undefined for simpler API without user data parameter

**Without TFS_READ_DIR_USERDATA:**
```c
uint8_t tfs_read_dir(void);
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item);
```

**With TFS_READ_DIR_USERDATA:**
```c
uint8_t tfs_read_dir(TFS_READ_DIR_USERDATA data);
uint8_t tfs_dir_handler(TFS_READ_DIR_USERDATA data, const TFS_DIR_ITEM *item);
```

**Example:**
```c
// For FUSE implementation that needs to pass filler context
typedef struct {
    void *buffer;
    fuse_fill_dir_t filler;
} TFS_READDIR_FILLER;

#define TFS_READ_DIR_USERDATA const TFS_READDIR_FILLER *
```

---

### `TFS_FILENAME_CMP`

Custom filename comparison macro.

```c
#define TFS_FILENAME_CMP(ref, cmp) filename_cmp(ref, cmp)
```

**Effect:**
- Overrides the default filename comparison (case-sensitive `strncmp`)
- No code size impact (unless custom function adds code)
- Allows case-insensitive or custom comparison logic

**Default behavior (if not defined):**
```c
#define TFS_FILENAME_CMP(ref, cmp) (strncmp(ref, cmp, TFS_NAME_LEN) == 0)
```

**When to use:**
- Define for case-insensitive filesystems (e.g., ZX81)
- Define for custom character encoding or normalization

**User must implement:**
```c
uint8_t filename_cmp(const char *ref, const char *cmp);
// Returns: non-zero if names match, zero if they don't
```

**Example (case-insensitive):**
```c
#define TFS_FILENAME_CMP(ref, cmp) filename_cmp(ref, cmp)

uint8_t filename_cmp(const char *ref, const char *cmp) {
    uint8_t i;
    for (i = 0; i < TFS_NAME_LEN; i++) {
        char r = ref[i];
        char c = cmp[i];
        // Convert to uppercase
        if (r >= 'a' && r <= 'z') r -= 32;
        if (c >= 'a' && c <= 'z') c -= 32;
        // Compare
        if (r != c) return 0;
        if (r == '\0') break;
    }
    return 1;
}
```

---

## Platform-Specific Macros

These are typically used for hardware abstraction and should be defined if your platform needs special handling.

### SPI Byte Transfer Macros

For platforms using SPI-based storage (SD/MMC cards):

```c
#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
```

These macros are used by the `mmc.c` driver if you're using the included MMC/SD card implementation.

---

## Configuration Examples

### Minimal Configuration (ZX81)

Extremely constrained system with ~1KB RAM for filesystem.

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

// Disable format support (format externally)
#undef TFS_ENABLE_FORMAT

// Disable extended API (no random access)
#undef TFS_EXTENDED_API

// No user data for directory handler
#undef TFS_READ_DIR_USERDATA

// Case-insensitive filename comparison
#define TFS_FILENAME_CMP(ref, cmp) filename_cmp(ref, cmp)
uint8_t filename_cmp(const char *ref, const char *cmp);

// SPI macros for MMC driver
#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif
```

**Features:**
- Read/write files sequentially only
- No formatting capability
- No random file access
- Case-insensitive filenames
- **Code size:** ~6-8 KB
- **RAM usage:** ~1 KB

---

### Medium Configuration (AVR)

Embedded system with moderate resources.

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

// Enable format support
#define TFS_ENABLE_FORMAT

// Disable extended API (sequential access only)
#undef TFS_EXTENDED_API

// No user data for directory handler
#undef TFS_READ_DIR_USERDATA

// SPI macros for MMC driver
#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif
```

**Features:**
- Can format devices
- Sequential file access only
- No random access
- Case-sensitive filenames (default)
- **Code size:** ~8-10 KB
- **RAM usage:** ~1 KB

---

### Full Configuration (Linux)

System with plenty of resources.

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#include <fuse.h>

// Enable all features
#define TFS_ENABLE_FORMAT
#define TFS_FORMAT_STATE_CALLBACK
#define TFS_EXTENDED_API
#define TFS_MAX_FDS 32

// User data for FUSE integration
typedef struct {
    void *buffer;
    fuse_fill_dir_t filler;
} TFS_READDIR_FILLER;

#define TFS_READ_DIR_USERDATA const TFS_READDIR_FILLER *

#endif
```

**Features:**
- Full formatting support with progress callbacks
- Random file access with file descriptors
- Up to 32 simultaneous open files
- User data in directory handler
- **Code size:** ~12-15 KB
- **RAM usage:** ~2-3 KB

---

### Custom Embedded Configuration

Embedded system with random access needs but limited file descriptors.

```c
#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

// Enable format support
#define TFS_ENABLE_FORMAT

// Enable format progress (have a display)
#define TFS_FORMAT_STATE_CALLBACK

// Enable extended API for random access
#define TFS_EXTENDED_API

// Limit file descriptors to save RAM
#define TFS_MAX_FDS 4  // Only 4 open files max

// SPI macros
#define spi_send_byte(b) spi_transfer_byte(b)
#define spi_rec_byte() spi_transfer_byte(0xff)
uint8_t spi_transfer_byte(uint8_t b);

#endif
```

**Features:**
- Formatting with progress display
- Random file access
- Limited to 4 open files
- **Code size:** ~11-13 KB
- **RAM usage:** ~1.2 KB

---

## Configuration Decision Guide

### Do you need to format devices from your application?

- **Yes** → `#define TFS_ENABLE_FORMAT`
- **No** → `#undef TFS_ENABLE_FORMAT`

### Do you need to show format progress?

- **Yes** → `#define TFS_FORMAT_STATE_CALLBACK` (requires `TFS_ENABLE_FORMAT`)
- **No** → `#undef TFS_FORMAT_STATE_CALLBACK`

### Do you need random file access or in-place file modification?

- **Yes** → `#define TFS_EXTENDED_API`
- **No** → `#undef TFS_EXTENDED_API`

### How many files need to be open simultaneously?

- **1-4** → `#define TFS_MAX_FDS 4`
- **5-16** → `#define TFS_MAX_FDS 16`
- **Many** → `#define TFS_MAX_FDS 32` (or higher)
- **N/A** → Extended API disabled, not applicable

### Do you need case-insensitive filenames?

- **Yes** → Define `TFS_FILENAME_CMP` with custom comparison
- **No** → Leave undefined (default case-sensitive)

### Do you need to pass context to directory handler?

- **Yes** → `#define TFS_READ_DIR_USERDATA <type>`
- **No** → `#undef TFS_READ_DIR_USERDATA`

---

## Resource Usage Summary

| Configuration | Code Size | RAM Usage | Features |
|---------------|-----------|-----------|----------|
| Minimal (ZX81) | ~6-8 KB | ~1.0 KB | Basic read/write only |
| Medium (AVR) | ~8-10 KB | ~1.0 KB | + Formatting |
| Medium+ | ~11-13 KB | ~1.2 KB | + Random access (4 FDs) |
| Full (Linux) | ~12-15 KB | ~2.0 KB | + 32 file descriptors |
| Full+ | ~12-15 KB | ~3.0 KB | + Progress callbacks + custom handlers |

**Notes:**
- Code size varies by compiler optimization settings
- RAM usage includes static buffers only (512 bytes × 2 + state variables)
- Extended API RAM = base + (TFS_MAX_FDS × 28 bytes)

---

## Testing Your Configuration

After creating your `filesys_conf.h`, compile and test with these checks:

### 1. Compilation Check
```bash
# Should compile without errors
gcc -c filesys.c -I. -o filesys.o
```

### 2. Code Size Check
```bash
# Check code size
size filesys.o

# For embedded platforms
avr-size filesys.o
```

### 3. Feature Check

Test that only enabled features are available:

```c
void test_config(void) {
    #ifdef TFS_ENABLE_FORMAT
        tfs_format();  // Should compile
    #else
        // tfs_format();  // Should not compile
    #endif
    
    #ifdef TFS_EXTENDED_API
        int8_t fd = tfs_open("test");  // Should compile
        tfs_close(fd);
    #else
        // int8_t fd = tfs_open("test");  // Should not compile
    #endif
}
```

---

## Common Configuration Mistakes

### 1. Forgetting to define TFS_ENABLE_FORMAT before TFS_FORMAT_STATE_CALLBACK

```c
// WRONG - TFS_FORMAT_STATE_CALLBACK without TFS_ENABLE_FORMAT
#undef TFS_ENABLE_FORMAT
#define TFS_FORMAT_STATE_CALLBACK  // Will have no effect!

// CORRECT
#define TFS_ENABLE_FORMAT
#define TFS_FORMAT_STATE_CALLBACK
```

### 2. Defining TFS_MAX_FDS without TFS_EXTENDED_API

```c
// WRONG - TFS_MAX_FDS without TFS_EXTENDED_API
#undef TFS_EXTENDED_API
#define TFS_MAX_FDS 16  // Will have no effect!

// CORRECT
#define TFS_EXTENDED_API
#define TFS_MAX_FDS 16
```

### 3. Not implementing required user functions

```c
// If you define:
#define TFS_FILENAME_CMP(ref, cmp) my_compare(ref, cmp)

// You must implement:
uint8_t my_compare(const char *ref, const char *cmp) {
    // ... implementation ...
}
```

### 4. Wrong TFS_FILENAME_CMP return value

```c
// WRONG - returns 0 for match (opposite of required)
uint8_t filename_cmp(const char *ref, const char *cmp) {
    return strcmp(ref, cmp);  // Returns 0 when equal
}

// CORRECT - returns non-zero for match
uint8_t filename_cmp(const char *ref, const char *cmp) {
    return strcmp(ref, cmp) == 0;  // Returns 1 when equal
}
```

---

## Conditional Compilation Reference

Quick reference for checking configuration in your code:

```c
// Check if formatting is enabled
#ifdef TFS_ENABLE_FORMAT
    // Formatting code
#endif

// Check if format callbacks are enabled
#ifdef TFS_FORMAT_STATE_CALLBACK
    // Progress callback code
#endif

// Check if extended API is enabled
#ifdef TFS_EXTENDED_API
    // File descriptor code
#endif

// Check if user data is enabled
#ifdef TFS_READ_DIR_USERDATA
    // Directory handler with user data
#else
    // Directory handler without user data
#endif
```
