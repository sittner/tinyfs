#include "err_handler.h"
#include "filesys.h"

#include <stdio.h>
#include <errno.h>

typedef struct {
  uint8_t val;
  const char *msg;
  int error;
} ERROR_ITEM;

static const ERROR_ITEM errors[] = {
  { .val = TFS_ERR_OK, .msg = "OK.", .error = 0 },
  { .val = TFS_ERR_NO_DEV, .msg = "No device found.", .error = ENODEV },
  { .val = TFS_ERR_IO, .msg = "I/O error.", .error = EIO },
  { .val = TFS_ERR_DISK_FULL, .msg = "Disk full.", .error = ENOSPC },
  { .val = TFS_ERR_FILE_EXIST, .msg = "File already exists", .error = EEXIST },
  { .val = TFS_ERR_NOT_EXIST, .msg = "File not exists.", .error = ENOENT },
  { .val = TFS_ERR_NOT_EMPTY, .msg = "Directory not empty.", .error = ENOTEMPTY },
  { .val = TFS_ERR_NO_NAME, .msg = "No filename given.", .error = EINVAL },
  { .val = TFS_ERR_NAME_INVAL, .msg = "Invalid filename.", .error = EINVAL },
  { .val = TFS_ERR_UNEXP_EOF, .msg = "Unexpected end of file.", .error = ESPIPE },
  { .val = TFS_ERR_NO_FREE_FD, .msg = "No free FD available.", .error = EMFILE },
  { .val = TFS_ERR_INVAL_FD, .msg = "Invalid file handle.", .error = EBADF },
  { .val = TFS_FILE_BUSY, .msg = "File is busy.", .error = ETXTBSY },
  { .val = 0, .msg = NULL, .error = 0 }
};

int check_error(const char *pfx) {
  const ERROR_ITEM *err;
  if (last_error == TFS_ERR_OK) {
    return 0;
  }

  for (err = errors; err->msg != NULL; err++) {
    if (err->val == last_error) {
      fprintf(stderr, "%s: %s.\n", pfx, err->msg);
      return -(err->error);
    }
  }

  fprintf(stderr, "%s: Unknown error %d.\n", pfx, last_error);
  return -EIO;
}

