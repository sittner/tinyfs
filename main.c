#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "filesys.h"
#include "mmc-emu.h"

/*
typedef struct {
  uint8_t manu_id;
  uint16_t oem_id;
  uint8_t prod_name[5];
  uint8_t prod_rev;
  uint32_t prod_serno;
  uint8_t reserved : 4;
  uint8_t mfd_year : 8;
  uint8_t mfd_month : 4;
  uint8_t crc : 7;
  uint8_t unused : 1;
} __attribute__((packed)) MMC_INFO_CID;

typedef struct {
  uint8_t taac;
  uint8_t nsac;
  uint8_t tran_speed;
  uint16_t ccc : 12;
  uint8_t read_bl_len : 4;
  uint8_t read_bl_partial : 1;
  uint8_t write_blk_misalign : 1;
  uint8_t read_blk_misalign : 1;
  uint8_t dsr_imp : 1;
  uint8_t reserved2 : 2;
  uint16_t c_size : 12;
  uint8_t vdd_r_curr_min : 3;
  uint8_t vdd_r_curr_max : 3;
  uint8_t vdd_w_curr_min : 3;
  uint8_t vdd_w_curr_max : 3;
  uint8_t c_size_mult : 3;
  uint8_t erase_blk_en : 1;
  uint8_t sector_size : 7;
  uint8_t wp_grp_size : 7;
  uint8_t wp_grp_enable : 1;
  uint8_t reserved3 : 2;
  uint8_t r2w_factor : 3;
  uint8_t write_bl_len : 4;
  uint8_t write_bl_partial : 1;
  uint8_t reserved4 : 5;
  uint8_t file_format_grp : 1;
  uint8_t copy : 1;
  uint8_t perm_write_protect : 1;
  uint8_t temp_write_protect : 1;
  uint8_t file_format : 2;
  uint8_t reserved5 : 2;
} __attribute__((packed)) MMC_INFO_CSD_V1;

typedef struct {
  uint8_t taac;
  uint8_t nsac;
  uint8_t tran_speed;
  uint16_t ccc : 12;
  uint8_t read_bl_len : 4;
  uint8_t read_bl_partial : 1;
  uint8_t write_blk_misalign : 1;
  uint8_t read_blk_misalign : 1;
  uint8_t dsr_imp : 1;
  uint8_t reserved1 : 6;
  uint32_t c_size : 22;
  uint8_t reserved2 : 1;
  uint8_t erase_blk_en : 1;
  uint8_t sector_size : 7;
  uint8_t wp_grp_size : 7;
  uint8_t wp_grp_enable : 1;
  uint8_t reserved3 : 2;
  uint8_t r2w_factor : 3;
  uint8_t write_bl_len : 4;
  uint8_t write_bl_partial : 1;
  uint8_t reserved4 : 5;
  uint8_t file_format_grp : 1;
  uint8_t copy : 1;
  uint8_t perm_write_protect : 1;
  uint8_t temp_write_protect : 1;
  uint8_t file_format : 2;
  uint8_t reserved5 : 2;
} __attribute__((packed)) MMC_INFO_CSD_V2;

typedef struct {
  uint8_t csd_struct : 2;
  uint8_t reserved : 6;
  union {
    MMC_INFO_CSD_V1 v1;
    MMC_INFO_CSD_V2 v2;
  };
  uint8_t crc : 7;
  uint8_t unused : 1;
} __attribute__((packed)) MMC_INFO_CSD;
*/

char *split(char *s) {
  s = strchr(s, ' ');
  if (s != NULL) {
    *(s++) = 0;
  }
  return s;
}

int main(void) {
  char *cmd = NULL;
  size_t bufLen = 0;
  ssize_t len = 0;
  char *params;

  if (dev_open("sdcard.img") < 0) {
    fprintf(stderr, "Failed open device (error %d).\n", errno);
    return 1;
  }

  tfs_init();

  while (1) {
    // read line from stdin
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

    // split command
    params = split(cmd);

    // handle commands
    if (strcmp(cmd, "exit") == 0) {
      break;
    }

    if (strcmp(cmd, "mkfs") == 0) {
      tfs_format();
      printf("err: %d\n", last_error);
      continue;
    }

    if (strcmp(cmd, "ls") == 0) {
      tfs_show_dir();
      printf("err: %d\n", last_error);
      continue;
    }

    if (strcmp(cmd, "cd") == 0) {
      tfs_change_dir(params);
      printf("err: %d\n", last_error);
      continue;
    }

    if (strcmp(cmd, "mkdir") == 0) {
      tfs_create_dir(params);
      printf("err: %d\n", last_error);
      continue;
    }

    printf("'%s'\n", cmd);
  }

  free(cmd);
  dev_close();

  return 0;
}

