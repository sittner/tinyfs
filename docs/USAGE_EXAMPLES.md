# TinyFS Usage Examples

This document provides practical code examples demonstrating how to use TinyFS in various scenarios.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Directory Operations](#directory-operations)
- [Basic File Operations](#basic-file-operations)
- [Extended API Operations](#extended-api-operations)
- [Error Handling](#error-handling)
- [Common Patterns](#common-patterns)

---

## Basic Setup

### Minimal Initialization

```c
#include "filesys.h"
#include <stdio.h>

int main(void) {
    // Initialize the filesystem
    tfs_init();
    
    // Check for errors
    if (tfs_last_error != TFS_ERR_OK) {
        if (tfs_last_error == TFS_ERR_NO_DEV) {
            printf("Error: No storage device detected\n");
        } else if (tfs_last_error == TFS_ERR_IO) {
            printf("Error: I/O error during initialization\n");
        } else {
            printf("Error: Initialization failed (%d)\n", tfs_last_error);
        }
        return 1;
    }
    
    printf("Filesystem initialized successfully\n");
    printf("Device type: %d\n", tfs_drive_info.type);
    printf("Total blocks: %u\n", tfs_drive_info.blk_count);
    
    return 0;
}
```

### Format and Initialize

```c
#include "filesys.h"
#include <stdio.h>

void format_and_init(void) {
    // Initialize to detect the device
    tfs_init();
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Failed to initialize device\n");
        return;
    }
    
    printf("Formatting device... This will erase all data!\n");
    
    // Format the device
    tfs_format();
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Format failed: %d\n", tfs_last_error);
        return;
    }
    
    printf("Format complete!\n");
    
    // Re-initialize after format
    tfs_init();
    printf("Ready to use\n");
}
```

### Format with Progress (if callbacks enabled)

```c
#ifdef TFS_FORMAT_STATE_CALLBACK

void tfs_format_state(uint8_t state) {
    switch (state) {
        case TFS_FORMAT_STATE_START:
            printf("\n=== Starting Format ===\n");
            break;
        case TFS_FORMAT_STATE_BITMAP_START:
            printf("Writing bitmap blocks...\n");
            break;
        case TFS_FORMAT_STATE_BITMAP_DONE:
            printf("\nBitmap complete\n");
            break;
        case TFS_FORMAT_STATE_ROOTDIR:
            printf("Creating root directory...\n");
            break;
        case TFS_FORMAT_STATE_DONE:
            printf("Format complete!\n");
            break;
    }
}

void tfs_format_progress(uint32_t pos, uint32_t max) {
    int percent = (pos * 100) / max;
    printf("\rProgress: %3d%% [%u/%u]", percent, pos, max);
    fflush(stdout);
}

#endif
```

---

## Directory Operations

### List Directory Contents

```c
#include "filesys.h"
#include <stdio.h>

// Define the directory handler
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
    // Skip free entries
    if (item->type == TFS_DIR_ITEM_FREE) {
        return 1;  // Continue
    }
    
    // Display file information
    if (item->type == TFS_DIR_ITEM_FILE) {
        printf("FILE: %-16s  %10u bytes\n", item->name, item->size);
    } else if (item->type == TFS_DIR_ITEM_DIR) {
        printf("DIR:  %-16s  <DIR>\n", item->name);
    }
    
    return 1;  // Continue iteration
}

void list_directory(void) {
    printf("\nDirectory listing:\n");
    printf("------------------------------------------------\n");
    
    tfs_read_dir();
    
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Error reading directory: %d\n", tfs_last_error);
    }
}
```

### Navigate Directory Tree

```c
#include "filesys.h"
#include <stdio.h>

void navigate_example(void) {
    // Start at root
    tfs_change_dir_root();
    printf("Current directory: /\n");
    
    // Create a subdirectory
    tfs_create_dir("documents");
    if (tfs_last_error == TFS_ERR_OK) {
        printf("Created directory: documents\n");
    } else if (tfs_last_error == TFS_ERR_FILE_EXIST) {
        printf("Directory already exists\n");
    }
    
    // Change to subdirectory
    tfs_change_dir("documents");
    if (tfs_last_error == TFS_ERR_OK) {
        printf("Changed to: /documents\n");
    }
    
    // Create another subdirectory
    tfs_create_dir("reports");
    tfs_change_dir("reports");
    printf("Changed to: /documents/reports\n");
    
    // Go up one level
    tfs_change_dir_parent();
    printf("Changed to: /documents\n");
    
    // Go to root
    tfs_change_dir_root();
    printf("Changed to: /\n");
}
```

### Count Files and Directories

```c
#include "filesys.h"
#include <stdio.h>

static int file_count = 0;
static int dir_count = 0;
static uint32_t total_size = 0;

uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
    if (item->type == TFS_DIR_ITEM_FILE) {
        file_count++;
        total_size += item->size;
    } else if (item->type == TFS_DIR_ITEM_DIR) {
        dir_count++;
    }
    return 1;
}

void count_files(void) {
    file_count = 0;
    dir_count = 0;
    total_size = 0;
    
    tfs_read_dir();
    
    printf("Statistics:\n");
    printf("  Files:       %d\n", file_count);
    printf("  Directories: %d\n", dir_count);
    printf("  Total size:  %u bytes\n", total_size);
}
```

---

## Basic File Operations

### Write a Text File

```c
#include "filesys.h"
#include <stdio.h>
#include <string.h>

void write_text_file(void) {
    const char *content = "Hello, World!\nThis is TinyFS.\n";
    uint32_t len = strlen(content);
    
    // Write file (overwrite if exists)
    tfs_write_file("greeting.txt", (const uint8_t*)content, len, 1);
    
    if (tfs_last_error == TFS_ERR_OK) {
        printf("File written successfully: %u bytes\n", len);
    } else if (tfs_last_error == TFS_ERR_DISK_FULL) {
        printf("Error: Disk is full\n");
    } else {
        printf("Error writing file: %d\n", tfs_last_error);
    }
}
```

### Read a Text File

```c
#include "filesys.h"
#include <stdio.h>

void read_text_file(void) {
    uint8_t buffer[1024];
    
    // Read file
    uint32_t bytes_read = tfs_read_file("greeting.txt", buffer, sizeof(buffer) - 1);
    
    if (tfs_last_error == TFS_ERR_OK) {
        // Null-terminate for printing
        buffer[bytes_read] = '\0';
        
        printf("File content (%u bytes):\n", bytes_read);
        printf("---\n%s\n---\n", buffer);
    } else if (tfs_last_error == TFS_ERR_NOT_EXIST) {
        printf("Error: File not found\n");
    } else {
        printf("Error reading file: %d\n", tfs_last_error);
    }
}
```

### Copy a File

```c
#include "filesys.h"
#include <stdio.h>
#include <stdlib.h>

void copy_file(const char *source, const char *dest) {
    uint8_t *buffer;
    uint32_t size;
    
    // Get file size first using stat (if extended API available)
    #ifdef TFS_EXTENDED_API
    TFS_DIR_ITEM *item = tfs_stat(source);
    if (item == NULL || item->type != TFS_DIR_ITEM_FILE) {
        printf("Error: Source file not found\n");
        return;
    }
    size = item->size;
    #else
    size = 65536;  // Assume maximum size
    #endif
    
    // Allocate buffer
    buffer = (uint8_t*)malloc(size);
    if (buffer == NULL) {
        printf("Error: Out of memory\n");
        return;
    }
    
    // Read source file
    uint32_t bytes_read = tfs_read_file(source, buffer, size);
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Error reading source file: %d\n", tfs_last_error);
        free(buffer);
        return;
    }
    
    // Write destination file
    tfs_write_file(dest, buffer, bytes_read, 1);
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Error writing destination file: %d\n", tfs_last_error);
    } else {
        printf("Copied %u bytes from '%s' to '%s'\n", bytes_read, source, dest);
    }
    
    free(buffer);
}
```

### Delete Files and Directories

```c
#include "filesys.h"
#include <stdio.h>

void delete_example(void) {
    // Delete a file
    tfs_delete("oldfile.txt");
    if (tfs_last_error == TFS_ERR_OK) {
        printf("File deleted\n");
    } else if (tfs_last_error == TFS_ERR_NOT_EXIST) {
        printf("File not found\n");
    }
    
    // Try to delete a directory (must be empty)
    tfs_delete("emptydir");
    if (tfs_last_error == TFS_ERR_OK) {
        printf("Directory deleted\n");
    } else if (tfs_last_error == TFS_ERR_NOT_EMPTY) {
        printf("Error: Directory is not empty\n");
    }
}
```

### Rename Files

```c
#include "filesys.h"
#include <stdio.h>

void rename_example(void) {
    // Rename a file
    tfs_rename("oldname.txt", "newname.txt");
    
    if (tfs_last_error == TFS_ERR_OK) {
        printf("File renamed successfully\n");
    } else if (tfs_last_error == TFS_ERR_NOT_EXIST) {
        printf("Error: Source file not found\n");
    } else if (tfs_last_error == TFS_ERR_FILE_EXIST) {
        printf("Error: Destination name already exists\n");
    }
}
```

---

## Extended API Operations

These examples require `TFS_EXTENDED_API` to be defined.

### Random Access Write

```c
#ifdef TFS_EXTENDED_API

#include "filesys.h"
#include <stdio.h>

void random_write_example(void) {
    int8_t fd;
    uint8_t data[4];
    uint32_t bytes_written;
    
    // Open file (create with touch if needed)
    fd = tfs_open("data.bin");
    if (fd < 0) {
        if (tfs_last_error == TFS_ERR_NOT_EXIST) {
            // Create empty file
            tfs_touch("data.bin");
            fd = tfs_open("data.bin");
        }
    }
    
    if (fd < 0) {
        printf("Failed to open file\n");
        return;
    }
    
    // Write at offset 0
    data[0] = 0x01; data[1] = 0x02; data[2] = 0x03; data[3] = 0x04;
    bytes_written = tfs_write(fd, data, 4, 0);
    printf("Wrote %u bytes at offset 0\n", bytes_written);
    
    // Write at offset 1000 (file auto-extends, gap filled with zeros)
    data[0] = 0xFF; data[1] = 0xFE; data[2] = 0xFD; data[3] = 0xFC;
    bytes_written = tfs_write(fd, data, 4, 1000);
    printf("Wrote %u bytes at offset 1000\n", bytes_written);
    
    // Write at offset 500
    data[0] = 0xAA; data[1] = 0xBB; data[2] = 0xCC; data[3] = 0xDD;
    bytes_written = tfs_write(fd, data, 4, 500);
    printf("Wrote %u bytes at offset 500\n", bytes_written);
    
    // Close file
    tfs_close(fd);
    printf("File closed\n");
}

#endif
```

### Random Access Read

```c
#ifdef TFS_EXTENDED_API

#include "filesys.h"
#include <stdio.h>

void random_read_example(void) {
    int8_t fd;
    uint8_t buffer[100];
    uint32_t bytes_read;
    
    // Open file
    fd = tfs_open("data.bin");
    if (fd < 0) {
        printf("Failed to open file\n");
        return;
    }
    
    // Read from beginning
    bytes_read = tfs_read(fd, buffer, 10, 0);
    printf("Read %u bytes from offset 0\n", bytes_read);
    
    // Read from middle
    bytes_read = tfs_read(fd, buffer, 20, 500);
    printf("Read %u bytes from offset 500\n", bytes_read);
    
    // Read from near end
    bytes_read = tfs_read(fd, buffer, 50, 950);
    printf("Read %u bytes from offset 950\n", bytes_read);
    
    // Close file
    tfs_close(fd);
}

#endif
```

### Modify File In-Place

```c
#ifdef TFS_EXTENDED_API

#include "filesys.h"
#include <stdio.h>
#include <string.h>

void modify_file_example(void) {
    int8_t fd;
    char buffer[100];
    uint32_t bytes;
    
    // Open file
    fd = tfs_open("config.txt");
    if (fd < 0) {
        printf("Failed to open file\n");
        return;
    }
    
    // Read first 50 bytes
    bytes = tfs_read(fd, (uint8_t*)buffer, 50, 0);
    buffer[bytes] = '\0';
    printf("Original content: %s\n", buffer);
    
    // Modify part of the file (overwrite bytes 10-20)
    const char *new_text = "MODIFIED";
    tfs_write(fd, (const uint8_t*)new_text, strlen(new_text), 10);
    
    // Read again to verify
    bytes = tfs_read(fd, (uint8_t*)buffer, 50, 0);
    buffer[bytes] = '\0';
    printf("Modified content: %s\n", buffer);
    
    // Close file
    tfs_close(fd);
}

#endif
```

### Truncate and Extend Files

```c
#ifdef TFS_EXTENDED_API

#include "filesys.h"
#include <stdio.h>

void truncate_example(void) {
    int8_t fd;
    TFS_DIR_ITEM *item;
    
    // Create a test file
    const char *data = "This is a test file with some content.";
    tfs_write_file("test.txt", (const uint8_t*)data, strlen(data), 1);
    
    // Check original size
    item = tfs_stat("test.txt");
    printf("Original size: %u bytes\n", item->size);
    
    // Open and truncate to 10 bytes
    fd = tfs_open("test.txt");
    if (fd >= 0) {
        tfs_trunc(fd, 10);
        tfs_close(fd);
        
        item = tfs_stat("test.txt");
        printf("After truncate to 10: %u bytes\n", item->size);
    }
    
    // Open and extend to 1000 bytes
    fd = tfs_open("test.txt");
    if (fd >= 0) {
        tfs_trunc(fd, 1000);
        tfs_close(fd);
        
        item = tfs_stat("test.txt");
        printf("After extend to 1000: %u bytes\n", item->size);
    }
    
    // Open and truncate to 0 (empty file)
    fd = tfs_open("test.txt");
    if (fd >= 0) {
        tfs_trunc(fd, 0);
        tfs_close(fd);
        
        item = tfs_stat("test.txt");
        printf("After truncate to 0: %u bytes\n", item->size);
    }
}

#endif
```

### Get File Information

```c
#ifdef TFS_EXTENDED_API

#include "filesys.h"
#include <stdio.h>

void stat_example(void) {
    TFS_DIR_ITEM *item;
    
    // Get information about a file
    item = tfs_stat("myfile.txt");
    
    if (item != NULL) {
        printf("Name: %.*s\n", TFS_NAME_LEN, item->name);
        printf("Type: %s\n", 
               item->type == TFS_DIR_ITEM_FILE ? "File" :
               item->type == TFS_DIR_ITEM_DIR ? "Directory" : "Unknown");
        printf("Size: %u bytes\n", item->size);
        printf("First block: %u\n", item->blk);
    } else {
        if (tfs_last_error == TFS_ERR_NOT_EXIST) {
            printf("File not found\n");
        } else {
            printf("Error: %d\n", tfs_last_error);
        }
    }
}

#endif
```

---

## Error Handling

### Comprehensive Error Handler

```c
#include "filesys.h"
#include <stdio.h>

const char* get_error_string(uint8_t error) {
    switch (error) {
        case TFS_ERR_OK:          return "No error";
        case TFS_ERR_NO_DEV:      return "No device detected";
        case TFS_ERR_IO:          return "I/O error";
        case TFS_ERR_DISK_FULL:   return "Disk full";
        case TFS_ERR_FILE_EXIST:  return "File already exists";
        case TFS_ERR_NOT_EXIST:   return "File/directory not found";
        case TFS_ERR_NOT_EMPTY:   return "Directory not empty";
        case TFS_ERR_NO_NAME:     return "No filename provided";
        case TFS_ERR_NAME_INVAL:  return "Invalid filename";
        case TFS_ERR_UNEXP_EOF:   return "Unexpected end of file";
#ifdef TFS_EXTENDED_API
        case TFS_ERR_NO_FREE_FD:  return "No free file descriptors";
        case TFS_ERR_INVAL_FD:    return "Invalid file descriptor";
        case TFS_FILE_BUSY:       return "File is currently open";
#endif
        default:                  return "Unknown error";
    }
}

void check_error(const char *operation) {
    if (tfs_last_error != TFS_ERR_OK) {
        printf("%s failed: %s (code %d)\n", 
               operation, 
               get_error_string(tfs_last_error),
               tfs_last_error);
    } else {
        printf("%s succeeded\n", operation);
    }
}

// Usage
void error_handling_example(void) {
    tfs_write_file("test.txt", (uint8_t*)"data", 4, 0);
    check_error("Write file");
    
    tfs_delete("nonexistent.txt");
    check_error("Delete file");
}
```

---

## Common Patterns

### Disk Usage Information

```c
#include "filesys.h"
#include <stdio.h>

void show_disk_usage(void) {
    uint32_t used = tfs_get_used();
    uint32_t total = tfs_drive_info.blk_count;
    uint32_t free = total - used;
    
    printf("\nDisk Usage:\n");
    printf("  Used blocks:  %10u (%u%%)\n", used, (used * 100) / total);
    printf("  Free blocks:  %10u (%u%%)\n", free, (free * 100) / total);
    printf("  Total blocks: %10u\n", total);
    printf("\n");
    printf("  Used space:   %10u KB\n", (used * 512) / 1024);
    printf("  Free space:   %10u KB\n", (free * 512) / 1024);
    printf("  Total space:  %10u KB\n", (total * 512) / 1024);
}
```

### Recursive Directory Delete

```c
#include "filesys.h"
#include <stdio.h>
#include <string.h>

// Simple implementation - not truly recursive due to memory constraints
void delete_directory_contents(void) {
    char names[20][TFS_NAME_LEN + 1];
    uint8_t types[20];
    int count = 0;
    
    // First pass: collect all names
    uint8_t handler(const TFS_DIR_ITEM *item) {
        if (item->type != TFS_DIR_ITEM_FREE && count < 20) {
            strncpy(names[count], item->name, TFS_NAME_LEN);
            names[count][TFS_NAME_LEN] = '\0';
            types[count] = item->type;
            count++;
        }
        return 1;
    }
    
    tfs_read_dir();
    
    // Second pass: delete all items
    for (int i = 0; i < count; i++) {
        if (types[i] == TFS_DIR_ITEM_FILE) {
            tfs_delete(names[i]);
            printf("Deleted file: %s\n", names[i]);
        } else if (types[i] == TFS_DIR_ITEM_DIR) {
            // For directories, would need to recurse
            // This simple version only deletes empty directories
            tfs_delete(names[i]);
            if (tfs_last_error == TFS_ERR_OK) {
                printf("Deleted directory: %s\n", names[i]);
            } else if (tfs_last_error == TFS_ERR_NOT_EMPTY) {
                printf("Skipped non-empty directory: %s\n", names[i]);
            }
        }
    }
}
```

### Simple Hex Dump

```c
#include "filesys.h"
#include <stdio.h>
#include <ctype.h>

void hex_dump_file(const char *filename) {
    uint8_t buffer[16];
    uint32_t offset = 0;
    uint32_t bytes_read;
    int i;
    
#ifdef TFS_EXTENDED_API
    int8_t fd = tfs_open(filename);
    if (fd < 0) {
        printf("Failed to open file\n");
        return;
    }
    
    printf("Hex dump of '%s':\n", filename);
    printf("Offset   Hex                                          ASCII\n");
    printf("-------- ------------------------------------------------ ----------------\n");
    
    while (1) {
        bytes_read = tfs_read(fd, buffer, sizeof(buffer), offset);
        if (bytes_read == 0) break;
        
        // Print offset
        printf("%08X ", offset);
        
        // Print hex
        for (i = 0; i < 16; i++) {
            if (i < bytes_read) {
                printf("%02X ", buffer[i]);
            } else {
                printf("   ");
            }
        }
        
        // Print ASCII
        printf(" ");
        for (i = 0; i < bytes_read; i++) {
            printf("%c", isprint(buffer[i]) ? buffer[i] : '.');
        }
        printf("\n");
        
        offset += bytes_read;
    }
    
    tfs_close(fd);
#else
    printf("Hex dump requires Extended API\n");
#endif
}
```

### Safe File Write with Backup

```c
#include "filesys.h"
#include <stdio.h>
#include <string.h>

void safe_write_file(const char *filename, const uint8_t *data, uint32_t len) {
    char backup_name[TFS_NAME_LEN];
    
    // Create backup name (append ".bak")
    strncpy(backup_name, filename, TFS_NAME_LEN - 4);
    backup_name[TFS_NAME_LEN - 4] = '\0';
    strcat(backup_name, ".bak");
    
    // Check if original file exists
    TFS_DIR_ITEM *item = tfs_stat(filename);
    if (item != NULL && item->type == TFS_DIR_ITEM_FILE) {
        // Rename original to backup
        tfs_delete(backup_name);  // Delete old backup if exists
        tfs_rename(filename, backup_name);
        if (tfs_last_error != TFS_ERR_OK) {
            printf("Warning: Failed to create backup\n");
        } else {
            printf("Created backup: %s\n", backup_name);
        }
    }
    
    // Write new file
    tfs_write_file(filename, data, len, 1);
    
    if (tfs_last_error == TFS_ERR_OK) {
        printf("File written successfully\n");
        // Optionally delete backup
        // tfs_delete(backup_name);
    } else {
        printf("Write failed: %d\n", tfs_last_error);
        // Optionally restore backup
        if (item != NULL) {
            tfs_rename(backup_name, filename);
            printf("Restored from backup\n");
        }
    }
}
```

---

## Complete Program Example

```c
#include "filesys.h"
#include <stdio.h>
#include <string.h>

// Directory handler for listing
uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
    if (item->type == TFS_DIR_ITEM_FREE) {
        return 1;
    }
    
    if (item->type == TFS_DIR_ITEM_FILE) {
        printf("  FILE: %-16s  %10u bytes\n", item->name, item->size);
    } else if (item->type == TFS_DIR_ITEM_DIR) {
        printf("  DIR:  %-16s\n", item->name);
    }
    
    return 1;
}

int main(void) {
    // Initialize filesystem
    printf("Initializing TinyFS...\n");
    tfs_init();
    
    if (tfs_last_error != TFS_ERR_OK) {
        printf("Initialization failed: %d\n", tfs_last_error);
        return 1;
    }
    
    printf("Device: %s\n", tfs_drive_info.model);
    printf("Blocks: %u\n", tfs_drive_info.blk_count);
    
    // Create a directory structure
    printf("\nCreating directory structure...\n");
    tfs_change_dir_root();
    tfs_create_dir("test");
    tfs_change_dir("test");
    
    // Write some files
    printf("\nWriting test files...\n");
    const char *msg1 = "Hello, World!";
    tfs_write_file("hello.txt", (const uint8_t*)msg1, strlen(msg1), 1);
    
    const char *msg2 = "This is a test file for TinyFS.";
    tfs_write_file("test.txt", (const uint8_t*)msg2, strlen(msg2), 1);
    
    // List directory
    printf("\nDirectory listing:\n");
    tfs_read_dir();
    
    // Read a file back
    printf("\nReading hello.txt:\n");
    uint8_t buffer[100];
    uint32_t bytes_read = tfs_read_file("hello.txt", buffer, sizeof(buffer));
    buffer[bytes_read] = '\0';
    printf("Content: %s\n", buffer);
    
    // Show disk usage
    printf("\nDisk usage:\n");
    uint32_t used = tfs_get_used();
    uint32_t total = tfs_drive_info.blk_count;
    printf("Used: %u / %u blocks (%u%%)\n", 
           used, total, (used * 100) / total);
    
    return 0;
}
```
