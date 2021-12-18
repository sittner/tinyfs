#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#include <fuse.h>

#define TFS_ENABLE_FORMAT
#define TFS_FORMAT_STATE_CALLBACK
#define TFS_EXTENDED_API
#define TFS_MAX_FDS 32

typedef struct {
  void *buffer;
  fuse_fill_dir_t filler;
} TFS_READDIR_FILLER;

#define TFS_READ_DIR_USERDATA const TFS_READDIR_FILLER *

#endif

