#include "util.h"

void scopy(char *dst, const char *src, uint8_t len) {
  for (; *src != 0 && len > 0; dst++, src++, len--) {
    *dst = *src;
  }
  *dst = 0;
}

