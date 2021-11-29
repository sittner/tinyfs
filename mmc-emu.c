#include "mmc-emu.h"

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

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
    strcpy(dev_info.model, "mmc-emu");
    strcpy(dev_info.fw, "N/A");
    strcpy(dev_info.serno, "N/A");
    dev_info.blk_count = st.st_size / TFS_BLOCKSIZE;
    return 0;
  }

  if (S_ISBLK(st.st_mode)) {
    uint64_t size;
    if (ioctl(dev_fd, BLKGETSIZE64, &size) < 0) {
      goto fail1;
    }

    strcpy(dev_info.model, "sd-card");
    strcpy(dev_info.fw, "N/A");
    strcpy(dev_info.serno, "N/A");
    dev_info.blk_count = size / TFS_BLOCKSIZE;
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

