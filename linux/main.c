#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "filesys.h"
#include "drive.h"

static char *split(char *s) {
  if (s == NULL) {
    return NULL;
  }

  s = strchr(s, ' ');
  if (s != NULL) {
    *(s++) = 0;
  }
  return s;
}

static int print_error(void) {
  if (last_error != TFS_ERR_OK) {
    printf("error %d.\n", last_error);
    return 1;
  }

  return 0;
}

static int dirs;
static int files;

uint8_t tfs_dir_handler(uint8_t mux, const TFS_DIR_ITEM *item) {
  // IMPORTANT: format string must match TFS_NAME_LEN
  // since name may not be null terminated
  switch (item->type) {
    case TFS_DIR_ITEM_DIR:
      dirs++;
      printf("     <DIR> %.16s\n", item->name);
      break;

    case TFS_DIR_ITEM_FILE:
      files++;
      printf("%10u %.16s\n", item->size, item->name);
      break;
  }

  return 1;
}

static uint8_t fileBuf[256 * 1024 * 1024];

int main(int argc, char **argv) {
  char *cmd = NULL;
  size_t bufLen = 0;
  ssize_t len = 0;
  char *params;
  char *fname;
  size_t fileLen;
  uint32_t used;
  FILE *filePtr;

  if (argc != 2) {
    fprintf(stderr, "usage: fstest <device/image file>	\n");
    return 1;
  }

  if (drive_open(argv[1]) < 0) {
    fprintf(stderr, "Failed open device (error %d).\n", errno);
    return 1;
  }

  tfs_init();

  while (1) {
    // read line from stdin
    printf("> ");
    if ((len = getline(&cmd, &bufLen, stdin)) < 0) {
      fprintf(stderr, "Failed to read from stdin: error %d\n", errno);
      break;
    }

    // trim line
    for (; len >= 0; len--) {
      if (len == 0 || strchr("\r\n\t ", cmd[len - 1]) == NULL) {
        cmd[len] = 0;
        break;
      }
    }

    // skip empty lines
    if (cmd[0] == 0) {
      continue;
    }

    // split command
    params = split(cmd);

    // handle commands
    if (strcmp(cmd, "exit") == 0) {
      break;
    }

    if (strcmp(cmd, "mkfs") == 0) {
      tfs_format();
      print_error();
      continue;
    }

    if (strcmp(cmd, "ls") == 0) {
      dirs = 0;
      files = 0;
      printf("      size name\n");
      tfs_read_dir(0);
      printf("%d dirs, %d files.\n", dirs, files);
      print_error();
      continue;
    }

    if (strcmp(cmd, "cd") == 0) {
      tfs_change_dir(params);
      print_error();
      continue;
    }

    if (strcmp(cmd, "md") == 0) {
      tfs_create_dir(params);
      print_error();
      continue;
    }

    if (strcmp(cmd, "rm") == 0) {
      tfs_delete(params);
      print_error();
      continue;
    }

    if (strcmp(cmd, "du") == 0) {
      used = tfs_get_used();
      if (print_error()) {
        continue;
      }
      printf("blocks used: %u/%u\n", used, drive_info.blk_count);
      continue;
    }

    if (strcmp(cmd, "mv") == 0) {
      fname = split(params);
      if (fname == NULL || fname[0] == 0 || params[0] == 0) {
        printf("usage: mv <old name> <new name>\n");
        continue;
      }

      tfs_rename(params, fname);
      print_error();
      continue;
    }

    if (strcmp(cmd, "rd") == 0) {
      fname = split(params);
      if (fname == NULL || fname[0] == 0 || params[0] == 0) {
        printf("usage: rd <tfs name> <local name>\n");
        continue;
      }

      fileLen = tfs_read_file(params, fileBuf, sizeof(fileBuf));
      if (print_error()) {
        continue;
      }

      filePtr = fopen(fname, "wb");
      if (filePtr == NULL) {
        printf("failed to open local file\n");
        continue;
      }

      fwrite(fileBuf, 1, fileLen, filePtr);
      fclose(filePtr);
      continue;
    }

    if (strcmp(cmd, "wr") == 0) {
      fname = split(params);
      if (fname == NULL || fname[0] == 0 || params[0] == 0) {
        printf("usage: wr <tfs name> <local name>\n");
        continue;
      }

      filePtr = fopen(fname, "rb");
      if (filePtr == NULL) {
        printf("failed to open local file\n");
        continue;
      }

      fileLen = fread(fileBuf, 1, sizeof(fileBuf), filePtr);
      fclose(filePtr);

      tfs_write_file(params, fileBuf, fileLen, 1);
      if (print_error()) {
        continue;
      }

      continue;
    }

    printf("Unknown command '%s'\n", cmd);
  }

  free(cmd);
  drive_close();

  return 0;
}

