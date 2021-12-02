#include "filesys.h"
#include "term.h"

#include <stdint.h>

void init(void) {
}

void save(uint8_t *name) {
  term_pos(3, 1);
  term_puts("Hello");

  term_zx2ascii(name);
  term_pos(0, 2);
  term_puts(term_buf);
}

void load(uint8_t *name) {
}

void tfs_format_state(uint8_t state) {
}

void tfs_format_progress(uint32_t pos, uint32_t max) {
}

void tfs_dir_handler(uint8_t mux, const TFS_DIR_ITEM *item) {
}

