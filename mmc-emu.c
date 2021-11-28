#include "mmc-emu.h"

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "util.h"

static int dev_fd;

int dev_open(const char *dev) {
  struct stat st;

  memset(&dev_info, 0, sizeof(TFS_DRIVE_INFO));

  dev_fd = open(dev, O_RDWR);
  if (dev_fd < 0) {
    goto fail0;
  }

  if (fstat(dev_fd, &st) < 0) {
    goto fail1;
  }

  if (S_ISREG(st.st_mode)) {
    printf("file (%lu)\n", st.st_size);
    scopy(dev_info.model, "", DRIVE_INFO_MODEL_LEN);
    scopy(dev_info.fw, "", DRIVE_INFO_FW_LEN);
    scopy(dev_info.serno, "", DRIVE_INFO_SERNO_LEN);
    dev_info.blk_count = st.st_size / TFS_BLOCKSIZE;
    return 0;
  }

fail1:
  close(dev_fd);
fail0:
  return -1;
}

int dev_close(void) {
  return close(dev_fd);
}

void dev_read_block(uint32_t blkno, void *data) {
  if (lseek(dev_fd, (off_t) blkno * TFS_BLOCKSIZE, SEEK_SET) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  if (read(dev_fd, data, TFS_BLOCKSIZE) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  last_error = TFS_ERR_OK;
}

void dev_write_block(uint32_t blkno, const void *data) {
  if (lseek(dev_fd, (off_t) blkno * TFS_BLOCKSIZE, SEEK_SET) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  if (write(dev_fd, data, TFS_BLOCKSIZE) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  last_error = TFS_ERR_OK;
}

