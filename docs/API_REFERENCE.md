# TinyFS API Reference

This document provides a comprehensive reference for all TinyFS public functions, organized by category.

## Table of Contents

- [Initialization Functions](#initialization-functions)
- [Formatting Functions](#formatting-functions)
- [Directory Operations](#directory-operations)
- [Basic File Operations](#basic-file-operations)
- [Extended File Operations](#extended-file-operations)
- [Utility Functions](#utility-functions)
- [Error Handling](#error-handling)
- [Data Structures](#data-structures)

---

## Initialization Functions

### `tfs_init()`

Initialize the TinyFS filesystem.

```c
void tfs_init(void);
```

**Description:**  
Initializes the filesystem by calling the platform-specific `drive_init()`, loading the first bitmap block, and setting up the initial directory pointer to the root directory.

**Parameters:** None

**Returns:** None

**Side Effects:**
- Sets `tfs_last_error` to indicate success or failure
- Calls `drive_init()`, `drive_select()`, and `drive_deselect()`
- Loads the first bitmap block into memory
- Initializes extended API file handles (if enabled)

**Usage Example:**
```c
tfs_init();
if (tfs_last_error != TFS_ERR_OK) {
    printf("Failed to initialize filesystem: %d\n", tfs_last_error);
    return;
}
printf("Filesystem initialized successfully\n");
```

---

### `drive_init()`

**User-Implemented Function**

Initialize the storage device hardware.

```c
void drive_init(void);
```

**Description:**  
Platform-specific function that must be implemented by the user. This function should:
- Initialize hardware (SPI, GPIO, etc.)
- Detect and initialize the storage device (SD card, MMC, etc.)
- Read device information (CSD, CID registers)
- Populate the `tfs_drive_info` structure
- Set `tfs_last_error` appropriately

**Parameters:** None

**Returns:** None

**Side Effects:**
- Must populate `tfs_drive_info.type`, `tfs_drive_info.blk_count`
- Should populate `tfs_drive_info.model`, `tfs_drive_info.serno` (optional)
- Must set `tfs_last_error = TFS_ERR_NO_DEV` if no device is detected
- Must set `tfs_last_error = TFS_ERR_IO` on communication errors
- Must set `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
void drive_init(void) {
    // Initialize SPI hardware
    spi_init();
    
    // Initialize MMC/SD card
    if (!mmc_init()) {
        tfs_last_error = TFS_ERR_NO_DEV;
        return;
    }
    
    // Populate drive info
    tfs_drive_info.type = DRIVE_TYPE_SDHC;
    tfs_drive_info.blk_count = mmc_get_block_count();
    strcpy(tfs_drive_info.model, "SanDisk SDHC");
    strcpy(tfs_drive_info.serno, "1234567890");
    
    tfs_last_error = TFS_ERR_OK;
}
```

---

### `drive_select()`

**User-Implemented Function**

Select/enable the storage device.

```c
void drive_select(void);
```

**Description:**  
Platform-specific function to enable or select the storage device. For SPI-based devices, this typically means pulling the chip select (CS) line low. Called before any block I/O operations.

**Parameters:** None

**Returns:** None

**Side Effects:** Platform-specific (e.g., GPIO pin state change)

**Usage Example:**
```c
void drive_select(void) {
    // Pull CS pin low to select SD card
    GPIO_CS_PORT &= ~GPIO_CS_PIN;
}
```

---

### `drive_deselect()`

**User-Implemented Function**

Deselect/disable the storage device.

```c
void drive_deselect(void);
```

**Description:**  
Platform-specific function to disable or deselect the storage device. For SPI-based devices, this typically means pulling the chip select (CS) line high. Called after block I/O operations are complete.

**Parameters:** None

**Returns:** None

**Side Effects:** Platform-specific (e.g., GPIO pin state change)

**Usage Example:**
```c
void drive_deselect(void) {
    // Pull CS pin high to deselect SD card
    GPIO_CS_PORT |= GPIO_CS_PIN;
}
```

---

### `drive_read_block()`

**User-Implemented Function**

Read a 512-byte block from the storage device.

```c
void drive_read_block(uint32_t blkno, uint8_t *data);
```

**Description:**  
Platform-specific function to read a single 512-byte block from the storage device. Must handle block addressing (byte address vs. block address for different card types).

**Parameters:**
- `blkno`: Block number to read (0-based)
- `data`: Pointer to 512-byte buffer to receive data

**Returns:** None

**Side Effects:**
- Fills `data` buffer with 512 bytes from the specified block
- Must set `tfs_last_error = TFS_ERR_IO` on read failure
- Must set `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
void drive_read_block(uint32_t blkno, uint8_t *data) {
    if (!mmc_read_block(blkno, data)) {
        tfs_last_error = TFS_ERR_IO;
    } else {
        tfs_last_error = TFS_ERR_OK;
    }
}
```

---

### `drive_write_block()`

**User-Implemented Function**

Write a 512-byte block to the storage device.

```c
void drive_write_block(uint32_t blkno, const uint8_t *data);
```

**Description:**  
Platform-specific function to write a single 512-byte block to the storage device. Must handle block addressing and wait for write completion.

**Parameters:**
- `blkno`: Block number to write (0-based)
- `data`: Pointer to 512-byte buffer containing data to write

**Returns:** None

**Side Effects:**
- Writes 512 bytes from `data` buffer to the specified block
- Must set `tfs_last_error = TFS_ERR_IO` on write failure
- Must set `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
void drive_write_block(uint32_t blkno, const uint8_t *data) {
    if (!mmc_write_block(blkno, data)) {
        tfs_last_error = TFS_ERR_IO;
    } else {
        tfs_last_error = TFS_ERR_OK;
    }
}
```

---

## Formatting Functions

These functions are only available when `TFS_ENABLE_FORMAT` is defined.

### `tfs_format()`

Format the storage device with TinyFS filesystem.

```c
void tfs_format(void);
```

**Description:**  
Formats the entire storage device with the TinyFS filesystem. This will:
1. Write bitmap blocks at regular intervals (every 4096 blocks)
2. Mark the bitmap blocks themselves as allocated
3. Mark blocks beyond the end of the device as allocated
4. Create the root directory at block 1
5. Set current directory to root

**⚠️ WARNING:** This operation destroys all existing data on the device.

**Parameters:** None

**Returns:** None

**Side Effects:**
- Erases all data on the storage device
- Sets `tfs_last_error` to indicate success or failure
- Calls format callbacks if `TFS_FORMAT_STATE_CALLBACK` is defined
- Initializes root directory

**Usage Example:**
```c
printf("Formatting device... This will erase all data!\n");
tfs_format();
if (tfs_last_error != TFS_ERR_OK) {
    printf("Format failed: %d\n", tfs_last_error);
} else {
    printf("Format successful\n");
}
```

---

### `tfs_format_state()`

**User-Implemented Function** (Optional)

Callback for format state changes.

```c
void tfs_format_state(uint8_t state);
```

**Description:**  
Optional callback function that receives notifications about format progress. Only called if `TFS_FORMAT_STATE_CALLBACK` is defined.

**Parameters:**
- `state`: Current format state (see Format States below)

**Returns:** None

**Format States:**
- `TFS_FORMAT_STATE_START` (0): Format operation starting
- `TFS_FORMAT_STATE_BITMAP_START` (1): Starting to write bitmap blocks
- `TFS_FORMAT_STATE_BITMAP_DONE` (2): Finished writing bitmap blocks
- `TFS_FORMAT_STATE_ROOTDIR` (3): Creating root directory
- `TFS_FORMAT_STATE_DONE` (4): Format complete

**Usage Example:**
```c
void tfs_format_state(uint8_t state) {
    switch (state) {
        case TFS_FORMAT_STATE_START:
            printf("Starting format...\n");
            break;
        case TFS_FORMAT_STATE_BITMAP_START:
            printf("Writing bitmap blocks...\n");
            break;
        case TFS_FORMAT_STATE_BITMAP_DONE:
            printf("Bitmap complete\n");
            break;
        case TFS_FORMAT_STATE_ROOTDIR:
            printf("Creating root directory...\n");
            break;
        case TFS_FORMAT_STATE_DONE:
            printf("Format complete!\n");
            break;
    }
}
```

---

### `tfs_format_progress()`

**User-Implemented Function** (Optional)

Callback for format progress updates.

```c
void tfs_format_progress(uint32_t pos, uint32_t max);
```

**Description:**  
Optional callback function that receives progress updates during the bitmap writing phase of formatting. Only called if `TFS_FORMAT_STATE_CALLBACK` is defined.

**Parameters:**
- `pos`: Current position (number of bitmap blocks written)
- `max`: Total number of bitmap blocks to write

**Returns:** None

**Usage Example:**
```c
void tfs_format_progress(uint32_t pos, uint32_t max) {
    int percent = (pos * 100) / max;
    printf("\rProgress: %d%% [%u/%u]", percent, pos, max);
    fflush(stdout);
}
```

---

## Directory Operations

### `tfs_read_dir()`

Read and enumerate directory contents.

```c
#ifdef TFS_READ_DIR_USERDATA
uint8_t tfs_read_dir(TFS_READ_DIR_USERDATA data);
#else
uint8_t tfs_read_dir(void);
#endif
```

**Description:**  
Iterates through all entries in the current directory, calling the user-defined `tfs_dir_handler()` function for each entry. The iteration stops if the handler returns 0 or when all entries have been processed.

**Parameters:**
- `data`: User-defined data to pass to handler (only if `TFS_READ_DIR_USERDATA` is defined)

**Returns:**
- `1`: Successfully read entire directory
- `0`: Stopped early (handler returned 0) or error occurred

**Side Effects:**
- Sets `tfs_last_error` to indicate success or failure
- Calls `tfs_dir_handler()` for each directory entry
- Does not change current directory

**Usage Example:**
```c
// Define the handler
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
    if (item->type == TFS_DIR_ITEM_FILE) {
        printf("FILE: %-16s  %10u bytes\n", item->name, item->size);
    } else if (item->type == TFS_DIR_ITEM_DIR) {
        printf("DIR:  %-16s\n", item->name);
    }
    return 1;  // Continue iteration
}

// List directory
printf("Directory listing:\n");
tfs_read_dir();
```

---

### `tfs_dir_handler()`

**User-Implemented Function**

Callback function to handle directory entries.

```c
#ifdef TFS_READ_DIR_USERDATA
uint8_t tfs_dir_handler(TFS_READ_DIR_USERDATA data, const TFS_DIR_ITEM *item);
#else
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item);
#endif
```

**Description:**  
User-defined callback function that is called for each entry in the directory during `tfs_read_dir()`. The function should process the entry and return 1 to continue or 0 to stop iteration.

**Parameters:**
- `data`: User-defined data (only if `TFS_READ_DIR_USERDATA` is defined)
- `item`: Pointer to directory item (see `TFS_DIR_ITEM` structure)

**Returns:**
- `1`: Continue iterating through directory
- `0`: Stop iteration immediately

**Notes:**
- The `item` pointer is only valid during the callback
- Items with `type == TFS_DIR_ITEM_FREE` should typically be ignored

**Usage Example:**
```c
// Count files and directories
int file_count = 0;
int dir_count = 0;

uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
    if (item->type == TFS_DIR_ITEM_FILE) {
        file_count++;
    } else if (item->type == TFS_DIR_ITEM_DIR) {
        dir_count++;
    }
    return 1;  // Continue
}

tfs_read_dir();
printf("Found %d files and %d directories\n", file_count, dir_count);
```

---

### `tfs_change_dir_root()`

Change current directory to root.

```c
void tfs_change_dir_root(void);
```

**Description:**  
Changes the current directory to the root directory. This is always block 1.

**Parameters:** None

**Returns:** None

**Side Effects:**
- Sets current directory to root
- Does not set `tfs_last_error`

**Usage Example:**
```c
// Go to root directory
tfs_change_dir_root();
printf("Changed to root directory\n");
```

---

### `tfs_change_dir_parent()`

Change current directory to parent directory.

```c
void tfs_change_dir_parent(void);
```

**Description:**  
Changes the current directory to its parent directory. If already at root, sets error.

**Parameters:** None

**Returns:** None

**Side Effects:**
- Changes current directory to parent
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if already at root
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
// Go up one level
tfs_change_dir_parent();
if (tfs_last_error == TFS_ERR_NOT_EXIST) {
    printf("Already at root directory\n");
} else if (tfs_last_error == TFS_ERR_OK) {
    printf("Changed to parent directory\n");
}
```

---

### `tfs_change_dir()`

Change to a subdirectory.

```c
void tfs_change_dir(const char *name);
```

**Description:**  
Changes the current directory to the specified subdirectory.

**Parameters:**
- `name`: Name of subdirectory (up to 16 characters)

**Returns:** None

**Side Effects:**
- Changes current directory if subdirectory exists
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if directory not found
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
tfs_change_dir("mydir");
if (tfs_last_error == TFS_ERR_NOT_EXIST) {
    printf("Directory 'mydir' not found\n");
} else {
    printf("Changed to directory 'mydir'\n");
}
```

---

### `tfs_create_dir()`

Create a new directory.

```c
void tfs_create_dir(const char *name);
```

**Description:**  
Creates a new subdirectory in the current directory.

**Parameters:**
- `name`: Name of directory to create (up to 16 characters)

**Returns:** None

**Side Effects:**
- Creates new directory if name is available
- Allocates a new directory block
- Sets `tfs_last_error = TFS_ERR_FILE_EXIST` if name already exists
- Sets `tfs_last_error = TFS_ERR_DISK_FULL` if no space available
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
tfs_create_dir("documents");
if (tfs_last_error == TFS_ERR_FILE_EXIST) {
    printf("Directory already exists\n");
} else if (tfs_last_error == TFS_ERR_DISK_FULL) {
    printf("Disk is full\n");
} else {
    printf("Directory created successfully\n");
}
```

---

## Basic File Operations

### `tfs_write_file()`

Write an entire file at once.

```c
void tfs_write_file(const char *name, const uint8_t *data, uint32_t len, uint8_t overwrite);
```

**Description:**  
Writes an entire file in a single operation. If the file exists and overwrite is enabled, the old file is deleted first.

**Parameters:**
- `name`: Filename (up to 16 characters)
- `data`: Pointer to data to write
- `len`: Number of bytes to write
- `overwrite`: If non-zero, overwrite existing file; if zero, fail if file exists

**Returns:** None

**Side Effects:**
- Creates or overwrites file
- Allocates data blocks as needed
- Frees old data blocks if overwriting
- Sets `tfs_last_error = TFS_ERR_FILE_EXIST` if file exists and overwrite is 0
- Sets `tfs_last_error = TFS_FILE_BUSY` if file is open (Extended API only)
- Sets `tfs_last_error = TFS_ERR_DISK_FULL` if no space available
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
const char *message = "Hello, World!";
tfs_write_file("greeting.txt", (uint8_t*)message, strlen(message), 1);
if (tfs_last_error == TFS_ERR_OK) {
    printf("File written successfully\n");
} else {
    printf("Write failed: %d\n", tfs_last_error);
}
```

---

### `tfs_read_file()`

Read an entire file at once.

```c
uint32_t tfs_read_file(const char *name, uint8_t *data, uint32_t max_len);
```

**Description:**  
Reads an entire file (or up to max_len bytes) in a single operation.

**Parameters:**
- `name`: Filename (up to 16 characters)
- `data`: Pointer to buffer to receive data
- `max_len`: Maximum number of bytes to read

**Returns:**
- Number of bytes actually read (up to max_len or file size, whichever is smaller)
- `0` if file not found or error occurred

**Side Effects:**
- Fills data buffer with file contents
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if file not found
- Sets `tfs_last_error = TFS_ERR_UNEXP_EOF` if file structure is corrupted
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
uint8_t buffer[1024];
uint32_t bytes_read = tfs_read_file("greeting.txt", buffer, sizeof(buffer));
if (tfs_last_error == TFS_ERR_OK) {
    printf("Read %u bytes\n", bytes_read);
    buffer[bytes_read] = '\0';  // Null-terminate for printing
    printf("Content: %s\n", buffer);
} else {
    printf("Read failed: %d\n", tfs_last_error);
}
```

---

### `tfs_delete()`

Delete a file or empty directory.

```c
#ifdef TFS_EXTENDED_API
void tfs_delete(const char *name, uint8_t type);
#else
void tfs_delete(const char *name);
#endif
```

**Description:**  
Deletes a file or directory. Directories must be empty before deletion.

**Parameters:**
- `name`: Name of file or directory to delete
- `type`: (Extended API only) Expected type: `TFS_DIR_ITEM_FILE`, `TFS_DIR_ITEM_DIR`, or `0` for any

**Returns:** None

**Side Effects:**
- Deletes file or directory if conditions are met
- Frees all data blocks (for files)
- Frees directory block (for directories)
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if not found
- Sets `tfs_last_error = TFS_ERR_NOT_EMPTY` if directory is not empty
- Sets `tfs_last_error = TFS_FILE_BUSY` if file is open (Extended API only)
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
// Basic API
tfs_delete("oldfile.txt");
if (tfs_last_error == TFS_ERR_OK) {
    printf("File deleted\n");
}

// Extended API - ensure it's a file, not a directory
tfs_delete("oldfile.txt", TFS_DIR_ITEM_FILE);
if (tfs_last_error == TFS_ERR_NOT_EXIST) {
    printf("File not found or is a directory\n");
}
```

---

### `tfs_rename()`

Rename a file or directory.

```c
void tfs_rename(const char *from, const char *to);
```

**Description:**  
Renames a file or directory within the same directory.

**Parameters:**
- `from`: Current name
- `to`: New name (up to 16 characters)

**Returns:** None

**Side Effects:**
- Renames file or directory if conditions are met
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if source not found
- Sets `tfs_last_error = TFS_ERR_FILE_EXIST` if target name already exists
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
tfs_rename("oldname.txt", "newname.txt");
if (tfs_last_error == TFS_ERR_OK) {
    printf("File renamed successfully\n");
} else if (tfs_last_error == TFS_ERR_FILE_EXIST) {
    printf("Target name already exists\n");
}
```

---

## Extended File Operations

These functions are only available when `TFS_EXTENDED_API` is defined. They provide file descriptor-based access with random read/write capabilities.

### `tfs_stat()`

Get information about a file or directory.

```c
TFS_DIR_ITEM *tfs_stat(const char *name);
```

**Description:**  
Returns information about a file or directory without opening it.

**Parameters:**
- `name`: Name of file or directory

**Returns:**
- Pointer to `TFS_DIR_ITEM` structure if found
- `NULL` if not found or error occurred

**Side Effects:**
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if not found
- Sets `tfs_last_error = TFS_ERR_OK` on success
- The returned pointer is only valid until the next filesystem operation

**Usage Example:**
```c
TFS_DIR_ITEM *item = tfs_stat("myfile.txt");
if (item != NULL && item->type == TFS_DIR_ITEM_FILE) {
    printf("File: %s\n", item->name);
    printf("Size: %u bytes\n", item->size);
    printf("First block: %u\n", item->blk);
} else {
    printf("File not found\n");
}
```

---

### `tfs_touch()`

Create an empty file.

```c
void tfs_touch(const char *name);
```

**Description:**  
Creates an empty file (0 bytes) if it doesn't already exist.

**Parameters:**
- `name`: Filename (up to 16 characters)

**Returns:** None

**Side Effects:**
- Creates empty file if name is available
- Does nothing if file already exists
- Sets `tfs_last_error = TFS_ERR_OK` always (even if file exists)

**Usage Example:**
```c
tfs_touch("newfile.txt");
if (tfs_last_error == TFS_ERR_OK) {
    printf("File created (or already exists)\n");
}
```

---

### `tfs_open()`

Open a file and get a file descriptor.

```c
int8_t tfs_open(const char *name);
```

**Description:**  
Opens a file for random access operations. Returns a file descriptor that can be used with `tfs_read()`, `tfs_write()`, `tfs_trunc()`, and `tfs_close()`.

**Parameters:**
- `name`: Filename (up to 16 characters)

**Returns:**
- File descriptor (0 to TFS_MAX_FDS-1) on success
- `-1` on failure

**Side Effects:**
- Allocates a file handle
- Multiple opens of the same file return the same descriptor and increment reference count
- Sets `tfs_last_error = TFS_ERR_NOT_EXIST` if file not found
- Sets `tfs_last_error = TFS_ERR_NO_FREE_FD` if no file descriptors available
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
int8_t fd = tfs_open("data.bin");
if (fd < 0) {
    printf("Failed to open file: %d\n", tfs_last_error);
    return;
}
printf("File opened, descriptor: %d\n", fd);
// ... use fd with tfs_read/write/trunc ...
tfs_close(fd);
```

---

### `tfs_close()`

Close a file descriptor.

```c
void tfs_close(int8_t fd);
```

**Description:**  
Closes a file descriptor. If the file was opened multiple times, decrements the reference count. The file handle is freed when the reference count reaches zero.

**Parameters:**
- `fd`: File descriptor returned by `tfs_open()`

**Returns:** None

**Side Effects:**
- Decrements file handle reference count
- Frees handle when reference count reaches zero
- Sets `tfs_last_error = TFS_ERR_INVAL_FD` if descriptor is invalid
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
int8_t fd = tfs_open("myfile.txt");
if (fd >= 0) {
    // ... use file ...
    tfs_close(fd);
    printf("File closed\n");
}
```

---

### `tfs_trunc()`

Truncate or extend a file to a specified size.

```c
void tfs_trunc(int8_t fd, uint32_t size);
```

**Description:**  
Changes the file size to the specified value. If the new size is smaller, excess data blocks are freed. If the new size is larger, the file is extended (new data is zero-filled).

**Parameters:**
- `fd`: File descriptor returned by `tfs_open()`
- `size`: New file size in bytes

**Returns:** None

**Side Effects:**
- Changes file size
- Frees excess blocks if shrinking
- Allocates new blocks if growing
- Updates directory entry with new size
- Sets `tfs_last_error = TFS_ERR_INVAL_FD` if descriptor is invalid
- Sets `tfs_last_error = TFS_ERR_DISK_FULL` if no space for expansion
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
int8_t fd = tfs_open("myfile.txt");
if (fd >= 0) {
    // Extend file to 1024 bytes
    tfs_trunc(fd, 1024);
    if (tfs_last_error == TFS_ERR_OK) {
        printf("File extended to 1024 bytes\n");
    }
    tfs_close(fd);
}
```

---

### `tfs_write()`

Write data at a specific offset.

```c
uint32_t tfs_write(int8_t fd, const uint8_t *data, uint32_t len, uint32_t offset);
```

**Description:**  
Writes data to the file at the specified offset. The file is automatically extended if writing beyond the current end. This is a random-access write operation.

**Parameters:**
- `fd`: File descriptor returned by `tfs_open()`
- `data`: Pointer to data to write
- `len`: Number of bytes to write
- `offset`: Byte offset in file where writing starts

**Returns:**
- Number of bytes actually written
- `0` on error

**Side Effects:**
- Writes data to file at specified offset
- Extends file if writing beyond current end
- Allocates new blocks as needed
- Updates directory entry if file size changed
- Sets `tfs_last_error = TFS_ERR_INVAL_FD` if descriptor is invalid
- Sets `tfs_last_error = TFS_ERR_DISK_FULL` if no space available
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
int8_t fd = tfs_open("data.bin");
if (fd >= 0) {
    uint8_t data[] = {0x01, 0x02, 0x03, 0x04};
    
    // Write at beginning
    tfs_write(fd, data, sizeof(data), 0);
    
    // Write at offset 1000
    tfs_write(fd, data, sizeof(data), 1000);
    
    printf("Data written at offsets 0 and 1000\n");
    tfs_close(fd);
}
```

---

### `tfs_read()`

Read data from a specific offset.

```c
uint32_t tfs_read(int8_t fd, uint8_t *data, uint32_t len, uint32_t offset);
```

**Description:**  
Reads data from the file starting at the specified offset. This is a random-access read operation. Reading beyond the end of the file returns fewer bytes than requested.

**Parameters:**
- `fd`: File descriptor returned by `tfs_open()`
- `data`: Pointer to buffer to receive data
- `len`: Maximum number of bytes to read
- `offset`: Byte offset in file where reading starts

**Returns:**
- Number of bytes actually read (may be less than `len` if near end of file)
- `0` if offset is beyond end of file or on error

**Side Effects:**
- Fills data buffer with file contents
- Sets `tfs_last_error = TFS_ERR_INVAL_FD` if descriptor is invalid
- Sets `tfs_last_error = TFS_ERR_OK` on success

**Usage Example:**
```c
int8_t fd = tfs_open("data.bin");
if (fd >= 0) {
    uint8_t buffer[100];
    
    // Read 100 bytes from offset 500
    uint32_t bytes_read = tfs_read(fd, buffer, sizeof(buffer), 500);
    
    printf("Read %u bytes from offset 500\n", bytes_read);
    tfs_close(fd);
}
```

---

## Utility Functions

### `tfs_get_used()`

Get the number of blocks currently in use.

```c
uint32_t tfs_get_used(void);
```

**Description:**  
Counts and returns the total number of allocated blocks on the filesystem. This is a slow operation as it must scan all bitmap blocks.

**Parameters:** None

**Returns:**
- Number of blocks in use
- `0` on error

**Side Effects:**
- Reads all bitmap blocks
- Sets `tfs_last_error` on I/O errors
- Does not change filesystem state

**Usage Example:**
```c
uint32_t used = tfs_get_used();
uint32_t total = tfs_drive_info.blk_count;
uint32_t free = total - used;
printf("Used: %u blocks\n", used);
printf("Free: %u blocks\n", free);
printf("Total: %u blocks\n", total);
printf("Usage: %u%%\n", (used * 100) / total);
```

---

## Error Handling

### Error Variable

```c
extern uint8_t tfs_last_error;
```

All TinyFS functions set the `tfs_last_error` global variable to indicate success or failure. Always check this variable after operations that may fail.

### Error Codes

#### Common Errors (Always Available)

```c
#define TFS_ERR_OK           0   // No error
#define TFS_ERR_NO_DEV       1   // No device detected
#define TFS_ERR_IO           2   // I/O error during read/write
#define TFS_ERR_DISK_FULL    3   // No free blocks available
#define TFS_ERR_FILE_EXIST   4   // File/directory already exists
#define TFS_ERR_NOT_EXIST    5   // File/directory does not exist
#define TFS_ERR_NOT_EMPTY    6   // Directory is not empty (cannot delete)
#define TFS_ERR_NO_NAME      7   // No filename provided (empty string)
#define TFS_ERR_NAME_INVAL   8   // Invalid filename
#define TFS_ERR_UNEXP_EOF    9   // Unexpected end of file (corrupted)
```

#### Extended API Errors (Only with `TFS_EXTENDED_API`)

```c
#define TFS_ERR_NO_FREE_FD  100  // No free file descriptors
#define TFS_ERR_INVAL_FD    101  // Invalid file descriptor
#define TFS_FILE_BUSY       102  // File is currently open
```

### Error Handling Example

```c
tfs_write_file("test.txt", data, len, 1);

switch (tfs_last_error) {
    case TFS_ERR_OK:
        printf("File written successfully\n");
        break;
    case TFS_ERR_DISK_FULL:
        printf("Error: Disk is full\n");
        break;
    case TFS_ERR_IO:
        printf("Error: I/O error occurred\n");
        break;
    case TFS_FILE_BUSY:
        printf("Error: File is currently open\n");
        break;
    default:
        printf("Error: Unknown error %d\n", tfs_last_error);
        break;
}
```

---

## Data Structures

### `TFS_DRIVE_INFO`

Information about the storage device.

```c
typedef struct {
    char model[DRIVE_INFO_MODEL_LEN + 1];    // Model string (33 chars)
    char serno[DRIVE_INFO_SERNO_LEN + 1];    // Serial number (21 chars)
    uint8_t type;                             // Drive type
    uint32_t blk_count;                       // Total blocks
} TFS_DRIVE_INFO;

extern TFS_DRIVE_INFO tfs_drive_info;
```

**Drive Types:**
```c
#define DRIVE_TYPE_EMU  0  // Emulated (e.g., file-backed)
#define DRIVE_TYPE_MMC  1  // MMC card
#define DRIVE_TYPE_SDV1 2  // SD card version 1.x
#define DRIVE_TYPE_SDV2 3  // SD card version 2.x (standard capacity)
#define DRIVE_TYPE_SDHC 4  // SD card version 2.x (high capacity)
```

### `TFS_DIR_ITEM`

Directory entry structure.

```c
typedef struct {
    uint32_t blk;                 // Block number (first data block or subdirectory)
    uint32_t size;                // File size in bytes (0 for directories)
    uint8_t type;                 // Entry type
    char name[TFS_NAME_LEN];      // Filename (16 chars, may not be null-terminated)
} TFS_DIR_ITEM;

#define TFS_NAME_LEN 16

#define TFS_DIR_ITEM_FREE 0  // Free entry
#define TFS_DIR_ITEM_DIR  1  // Directory
#define TFS_DIR_ITEM_FILE 2  // File
```

**Note:** The `name` field may not be null-terminated if the filename is exactly 16 characters long. Always use `strncpy()` or similar when copying names.

---

## Function Summary Table

| Function | Category | Basic API | Extended API | Description |
|----------|----------|-----------|--------------|-------------|
| `tfs_init()` | Init | ✓ | ✓ | Initialize filesystem |
| `tfs_format()` | Format | Optional | Optional | Format device |
| `tfs_read_dir()` | Directory | ✓ | ✓ | List directory contents |
| `tfs_change_dir_root()` | Directory | ✓ | ✓ | Change to root |
| `tfs_change_dir_parent()` | Directory | ✓ | ✓ | Change to parent |
| `tfs_change_dir()` | Directory | ✓ | ✓ | Change to subdirectory |
| `tfs_create_dir()` | Directory | ✓ | ✓ | Create directory |
| `tfs_write_file()` | File | ✓ | ✓ | Write entire file |
| `tfs_read_file()` | File | ✓ | ✓ | Read entire file |
| `tfs_delete()` | File | ✓ | ✓ | Delete file/directory |
| `tfs_rename()` | File | ✓ | ✓ | Rename file/directory |
| `tfs_stat()` | File | - | ✓ | Get file info |
| `tfs_touch()` | File | - | ✓ | Create empty file |
| `tfs_open()` | File | - | ✓ | Open file |
| `tfs_close()` | File | - | ✓ | Close file |
| `tfs_trunc()` | File | - | ✓ | Truncate/extend file |
| `tfs_write()` | File | - | ✓ | Random write |
| `tfs_read()` | File | - | ✓ | Random read |
| `tfs_get_used()` | Utility | ✓ | ✓ | Get used blocks |
