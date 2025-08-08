#include <avr/io.h>
#include <avr/pgmspace.h>
#include <avr/sleep.h>

#include "filesys.h"
#include "mmc.h"
#include "spi.h"
#include "uart.h"

#include <string.h>

static uint8_t read_line(char* buffer, uint8_t buffer_length) {
  char c;
  uint8_t len = 0;

  while (1) {
    c = uart_getc();

    // handle backspace
    if (c == 0x08 || c == 0x7f) {
      if (len == 0) {
        continue;
      }

      len--;

      uart_putc(0x08);
      uart_putc(' ');
      uart_putc(0x08);

      continue;
    }

    // handle enter
    if (c == '\n') {
      uart_putc('\n');
      buffer[len] = 0;
      return len;
    }

    if (len < (buffer_length - 1)) {
      uart_putc(c);
      buffer[len++] = c;
    }
  }
}

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
  if (tfs_last_error != TFS_ERR_OK) {
    uart_puts_p(PSTR("error "));
    uart_putw_dec(tfs_last_error);
    uart_putc('.');
    uart_putc('\n');
    return 1;
  }

  return 0;
}

static uint16_t dirs;
static uint16_t files;

uint8_t tfs_dir_handler(const TFS_DIR_ITEM *item) {
  uint32_t w = item->size;
  uint32_t num = 1000000000;
  uint8_t started = 0;
  uint8_t b;
  const char *c;

  switch (item->type) {
    case TFS_DIR_ITEM_DIR:
      dirs++;
      uart_puts_p(PSTR("     <DIR>"));
      break;

    case TFS_DIR_ITEM_FILE:
      files++;
      while(num > 0) {
        uint8_t b = w / num;
        if(b > 0 || started || num == 1) {
          uart_putc('0' + b);
          started = 1;
        } else {
          uart_putc(' ');
        }
        w -= b * num;
        num /= 10;
      }
      break;

    default:
      return 1;
  }

  // print name
  uart_putc(' ');
  for (b = 0, c = item->name; b < TFS_NAME_LEN && *c != 0; b++, c++) {
    uart_putc(*c);
  }
  uart_putc('\n');

  return 1;
}

int main(void) {
  char cmd[128];
  uint8_t len;
  char *params;
  char *fname;
  uint32_t used;

  // we will just use ordinary idle mode */
  set_sleep_mode(SLEEP_MODE_IDLE);

  // setup uart
  uart_init();

  // setup_spi
  spi_init();

  if (!drive_init()) {
    uart_puts_p(PSTR("failed to initialize sd card.\n"));
    return 1;
  }

  tfs_init();

  uart_puts_p(PSTR("\nblock count: "));
  uart_putdw_dec(tfs_drive_info.blk_count);
  uart_puts_p(PSTR("\nmodel: "));
  uart_puts(tfs_drive_info.model);
  uart_puts_p(PSTR("\nserno: "));
  uart_puts(tfs_drive_info.serno);
  uart_putc('\n');

  while(1) {
    // read line from uart
    uart_putc('>');
    uart_putc(' ');
    if ((len = read_line(cmd, sizeof(cmd))) < 1) {
      continue;
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
      uart_puts_p(PSTR("      size name\n"));
      tfs_read_dir();

      uart_putw_dec(dirs);
      uart_puts_p(PSTR(" dirs, "));
      uart_putw_dec(files);
      uart_puts_p(PSTR(" files.\n"));
      print_error();
      continue;
    }

    if (strcmp(cmd, "cd") == 0) {
      if (strcmp(params, "/") == 0) {
        tfs_change_dir_root();
      } else if (strcmp(params, "..") == 0) {
        tfs_change_dir_parent();
      } else {
        tfs_change_dir(params);
      }
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
      uart_puts_p(PSTR("blocks used: "));
      uart_putdw_dec(used);
      uart_putc('/');
      uart_putdw_dec(tfs_drive_info.blk_count);
      uart_putc('\n');
      continue;
    }

    if (strcmp(cmd, "mv") == 0) {
      fname = split(params);
      if (fname == NULL || fname[0] == 0 || params[0] == 0) {
        uart_puts_p(PSTR("usage: mv <old name> <new name>\n"));
        continue;
      }

      tfs_rename(params, fname);
      print_error();
      continue;
    }

    uart_puts_p(PSTR("Unknown command '")); uart_puts(cmd); uart_putc('\''); uart_putc('\n');
  }
}

