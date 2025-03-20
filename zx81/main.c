#include "filesys.h"
#include "mmc.h"
#include "term.h"

#include <stdint.h>
#include <string.h>

#define MAX_FILESIZE 16384

static volatile uint8_t   __at (16393) VERSN;
static volatile uint8_t * __at (16404) E_LINE;

static const char * const error_msg[] = {
  "no sd card",
  "i/o error",
  "disk full",
  "file allready exists",
  "file not exists",
  "dir not empty",
  "no filename",
  "invalid filename",
  "unexpected end of file"
};

static const char * const drive_types[] = {
  "emulated disk",
  "mmc card",
  "sd card v1",
  "sd card v2",
  "sdhc card"
};

static uint8_t init_ok;
static uint8_t dir_line;
static uint16_t dir_files;
static uint16_t dir_dirs;

static void print_dir_header(void);

static void show_drive_info(uint8_t show_used);

void init(void) {
  spi_deselect_drive();
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
*** SAVE ":$"               - format disk
*** SAVE ":>[DIRNAME]"      - create dir DIRNAME
*** SAVE ":=[OLD]:[NEW]"    - rename file [OLD] to [NEW]
*** SAVE ":-[FILENAME]"     - delete file [FILENAME]
*** SAVE ":[FILENAME]"      - save file FILENAME
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
    case '>':
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

    case '-':
      tfs_delete(&term_buf[2]);
      return;

    case '$':
#ifdef TFS_ENABLE_FORMAT
      tfs_format();
      return;
#endif

    // forbid load prefixes
    case '?':
    case '*':
    case '/':
    case '<':
      last_error = TFS_ERR_NAME_INVAL;
      return;


    default:
      tfs_write_file(&term_buf[1], &VERSN, E_LINE - &VERSN + 1, 1);
      return;
   }
}

/**********************************************************
*** load extension
***
*** syntax:
*** LOAD ":"           - show current dir
*** LOAD ":?"          - show drive info
*** LOAD ":*"          - show drive info with used blocks
*** LOAD ":/"          - change to root dir
*** LOAD ":<"          - change to parent dir
*** LOAD ":>[DIRNAME]" - change to DIRNAME
*** LOAD ":[FILENAME]" - load file FILENAME
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
      if (tfs_read_dir()) {
        term_puts("files: "); term_putul(dir_files);
        term_puts(" dirs: "); term_putul(dir_dirs);
      }
      return;

    case '?':
      show_drive_info(0);
      return;

    case '*':
      show_drive_info(1);
      return;

    case '/':
      tfs_change_dir_root();
      return;

    case '<':
      tfs_change_dir_parent();
      return;

    case '>':
      tfs_change_dir(&term_buf[2]);
      return;

    default:
      tfs_read_file(&term_buf[1], &VERSN, MAX_FILESIZE);
      return;
   }
}

void show_error(void) {
  if (last_error == 0) {
    return;
  }

  term_clrscrn();
  term_puts(error_msg[last_error - 1]);
}

static void print_dir_header(void) {
  term_clrscrn();
  term_puts("      size name\n");
  dir_line = 1;
}

uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
  uint16_t key;

  switch (item->type) {
    case TFS_DIR_ITEM_DIR:
      dir_dirs++;
      term_puts("     <DIR>");
      break;
    case TFS_DIR_ITEM_FILE:
      dir_files++;
      term_putul_aligned(item->size, 10);
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

static void show_drive_info(uint8_t show_used) {
  term_clrscrn();

  term_puts(" model: ");
  term_puts(drive_info.model);

  term_puts("\n serno: ");
  term_puts(drive_info.serno);

  term_puts("\n  type: ");
  term_puts(drive_types[drive_info.type]);

  term_puts("\nblocks: ");
  term_putul(drive_info.blk_count);

  if (show_used) {
    term_puts("\n  used: ");
    term_putul(tfs_get_used());
  }
}

uint8_t filename_cmp(const char *ref, const char *cmp) {
  uint8_t i;
  char c;

  for (i = 0; i < TFS_NAME_LEN; ref++, cmp++, i++) {
    c = *cmp;
    // ref is always lowercase, so convert cmp, if needed
    if (c >= 'A' && c <= 'Z') {
      c = c - 'A' + 'a';
    }
    if (c != *ref) {
      return 0;
    }
    if (c == 0) {
      return 1;
    }
  }

  return (*ref == 0);
}

