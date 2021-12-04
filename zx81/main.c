#include "filesys.h"
#include "mmc.h"
#include "term.h"

#include <stdint.h>
#include <string.h>

#define MAX_FILESIZE 16384

static volatile uint8_t   __at 16393 VERSN;
static volatile uint8_t * __at 16404 E_LINE;

static const char const *error_msg[] = {
  "no sd card",
  "io error",
  "disk full",
  "file allready exists",
  "file not exists",
  "dir not empty",
  "no filename",
  "invalid filename",
  "unexp. eof",
};

static uint8_t init_ok;
static uint8_t dir_line;
static uint16_t dir_files;
static uint16_t dir_dirs;

static void print_dir_header(void);

static void show_drive_info(void);

void init(void) {
  init_ok = drive_init();
  if (!init_ok) {
    return;
  }

  tfs_init();
}

/**********************************************************
*** save extension
***
*** syntax:
*** SAVE ":[FILENAME]"      - save file FILENAME
*** SAVE ":/[DIRNAME]"      - create dir DIRNAME
*** SAVE ":=[OLD]:[NEW]"    - rename file [OLD] to [NEW]
*** SAVE ":<[FILENAME]"     - delete file [FILENAME]
*** SAVE ":$"               - format disk
***
**********************************************************/
void save(uint8_t *name) {
  char *p;

  if (!init_ok) {
    last_error = TFS_ERR_NO_DEV;
    return;
  }

  term_zx2ascii(name);

  switch (term_buf[1]) {
    case '/':
      tfs_create_dir(&term_buf[2]);
      return;

    case '=':
      p = strchr(&term_buf[2], ':');
      if (p == NULL) {
        last_error = TFS_ERR_NO_NAME;
        return;
      }

      *(p++) = 0;
      tfs_rename(&term_buf[2], p);
      return;

    case '<':
      tfs_delete(&term_buf[2]);
      return;

    case '$':
      tfs_format();
      return;

    default:
      tfs_write_file(&name[1], &VERSN, E_LINE - &VERSN + 1, 1);
      return;
   }
}

/**********************************************************
*** load extension
***
*** syntax:
*** LOAD ":[FILENAME]" - load file FILENAME
*** LOAD ":?"          - show drive info
*** LOAD ":"           - show current dir
*** LOAD "://"         - change to root dir
*** LOAD ":/."         - change to parent dir
*** LOAD ":/[DIRNAME]" - change to DIRNAME
***
**********************************************************/
void load(uint8_t *name) {
  if (!init_ok) {
    last_error = TFS_ERR_NO_DEV;
    return;
  }

  term_zx2ascii(name);

  switch (term_buf[1]) {
    case 0:
      print_dir_header();
      dir_files = 0;
      dir_dirs = 0;
      tfs_read_dir(0);
      term_puts("files: "); term_putul(dir_files);
      term_puts("dirs: "); term_putul(dir_dirs);
      return;

    case '?':
      show_drive_info();
      return;

    case '/':
      tfs_change_dir(&term_buf[2]);
      return;

    default:
      tfs_read_file(&term_buf[1], &VERSN, MAX_FILESIZE);
      return;
   }
}

void show_error() {
  if (last_error == 0) {
    return;
  }

  term_clrscrn();
  term_puts("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n        ");
  term_puts(error_msg[last_error - 1]);
}

static void print_dir_header(void) {
  term_clrscrn();
  term_puts("      size name\n");
  dir_line = 1;
}

uint8_t tfs_dir_handler(uint8_t mux, const TFS_DIR_ITEM *item) {
  uint16_t key;

  (void) mux; // keep compiler happy

  switch (item->type) {
    case TFS_DIR_ITEM_DIR:
      dir_dirs++;
      term_puts("     <DIR>");
      break;
    case TFS_DIR_ITEM_FILE:
      dir_files++;
      term_putul(item->size);
      break;
    default:
      return 1;
  }

  term_putc(' ');
  term_putsn(item->name, TFS_NAME_LEN);
  term_putc('\n');

  // wait on page end
  dir_line++;
  if (dir_line >= 21) {
    term_puts("<NL> = next page  <SPACE> = end");
    while (1) {
      key = term_get_key();
      if (key == TERM_KEY_ENT) {
        print_dir_header();
        break;
      }
      if (key == TERM_KEY_SPC) {
        return 0;
      }
    }
  }

  return 1;
}

static void show_drive_info(void) {
  term_clrscrn();

  term_puts("model: ");
  term_puts(drive_info.model);

  term_puts("\nserno: ");
  term_puts(drive_info.serno);

  term_puts("\ntype: ");
  term_putul(drive_info.type);

  term_puts("\nblocks: ");
  term_putul(drive_info.blk_count);

  term_puts("\nused: ");
  term_putul(tfs_get_used());
}

