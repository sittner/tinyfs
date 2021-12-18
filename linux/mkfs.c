#include <stdio.h>
#include <errno.h>

#include "filesys.h"
#include "drive.h"
#include "err_handler.h"

int main(int argc, char **argv) {
  int ret = 0;

  if (argc != 2) {
    fprintf(stderr, "usage: fstest <device/image file>	\n");
    return 1;
  }

  if (drive_open(argv[1]) < 0) {
    fprintf(stderr, "Failed open device (error %d).\n", errno);
    return 1;
  }

  tfs_init();

  tfs_format();
  if (check_error("tfs_format")) {
    ret = 1;
  }

  drive_close();

  return ret;
}

void tfs_format_state(uint8_t state) {
  switch (state) {
    case TFS_FORMAT_STATE_START:
      printf("formating disk, please wait...\n");
      return;
    case TFS_FORMAT_STATE_BITMAP_START:
      printf("writing bitmap-blocks:\n");
      return;
    case TFS_FORMAT_STATE_BITMAP_DONE:
      printf("\n");
      return;
    case TFS_FORMAT_STATE_ROOTDIR:
      printf("creating root-directory.\n");
      return;
    case TFS_FORMAT_STATE_DONE:
      printf("DONE!\n");
      return;
  }

}

void tfs_format_progress(uint32_t pos, uint32_t max) {
  printf("  %u/%u\r", pos, max);
}

uint8_t tfs_dir_handler(TFS_READ_DIR_USERDATA filler, const TFS_DIR_ITEM *item) {
  return 1;
}

