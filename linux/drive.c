#include "drive.h"

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

static int drive_fd;

int drive_open(const char *dev) {
  struct stat st;

  memset(&drive_info, 0, sizeof(TFS_DRIVE_INFO));

  drive_fd = open(dev, O_RDWR);
  if (drive_fd < 0) {
    goto fail0;
  }

  if (fstat(drive_fd, &st) < 0) {
    goto fail1;
  }

  if (S_ISREG(st.st_mode)) {
    strcpy(drive_info.model, "mmc-emu");
    strcpy(drive_info.serno, "N/A");
    drive_info.blk_count = st.st_size / TFS_BLOCKSIZE;
    return 0;
  }

  if (S_ISBLK(st.st_mode)) {
    uint64_t size;
    if (ioctl(drive_fd, BLKGETSIZE64, &size) < 0) {
      goto fail1;
    }

    strcpy(drive_info.model, "sd-card");
    strcpy(drive_info.serno, "N/A");
    drive_info.blk_count = size / TFS_BLOCKSIZE;
    return 0;
  }

fail1:
  close(drive_fd);
fail0:
  return -1;
}

int drive_close(void) {
  return close(drive_fd);
}

void drive_read_block(uint32_t blkno, uint8_t *data) {
  if (lseek(drive_fd, (off_t) blkno * TFS_BLOCKSIZE, SEEK_SET) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  if (read(drive_fd, data, TFS_BLOCKSIZE) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  last_error = TFS_ERR_OK;
}

void drive_write_block(uint32_t blkno, const uint8_t *data) {
  if (lseek(drive_fd, (off_t) blkno * TFS_BLOCKSIZE, SEEK_SET) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  if (write(drive_fd, data, TFS_BLOCKSIZE) < 0) {
    last_error = TFS_ERR_IO;
    return;
  }

  last_error = TFS_ERR_OK;
}

void drive_select(void) {
  // dummy
}

void drive_deselect(void) {
  // dummy
}

