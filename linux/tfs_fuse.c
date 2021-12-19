#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <fuse.h>
#include <libgen.h>
#include <limits.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>

#include "filesys.h"
#include "drive.h"
#include "err_handler.h"

static uid_t my_uid;

static const char *travel_path(const char *path) {
  char *rw;
  int pos, tok;

  pos = 0;
  if (path[pos] == '/') {
    pos++;
    tfs_change_dir("/");
    if (last_error != TFS_ERR_OK) {
      return NULL;
    }
  }

  rw = strdup(path);
  if (rw == NULL) {
    last_error = TFS_ERR_IO;
    return NULL;
  }

  for (tok = pos; path[pos] != 0; pos++) {
    if (path[pos] == '/') {
      rw[pos]= 0;
      if (rw[tok] != 0) {
        if (strlen(&rw[tok]) > TFS_NAME_LEN) {
          last_error = TFS_ERR_NOT_EXIST;
          free(rw);
          return NULL;
        }
        tfs_change_dir(&rw[tok]);
        if (last_error != TFS_ERR_OK) {
          free(rw);
          return NULL;
        }
      }
      tok = pos + 1;
    }
  }

  free(rw);
  return &path[tok];
}

static int item_to_stat(const TFS_DIR_ITEM *item, struct stat *st) {
  if (item->type == TFS_DIR_ITEM_DIR) {
    st->st_mode = S_IFDIR | 0755;
    return 0;
  }

  if (item->type == TFS_DIR_ITEM_FILE) {
    st->st_mode = S_IFREG | 0755;
    st->st_size = item->size;
    return 0;
  }

  return 1;
}

static int op_getattr(const char *path, struct stat *st) {
  int err;
  TFS_DIR_ITEM *item;

  st->st_uid = my_uid;
  st->st_gid = my_uid;
  st->st_nlink = 1;

  // handle root directory
  if (strcmp( path, "/" ) == 0) {
    st->st_mode = S_IFDIR | 0755;
    return 0;
  }

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_getattr:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  item = tfs_stat(path);
  err = check_error("op_getattr:tfs_getattr");
  if (err < 0) {
    return err;
  }

  if (item == NULL) {
    return -ENOENT;
  }

  return item_to_stat(item, st);
}

static int op_readdir(const char *path, void *buffer, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info *fi) {
  const TFS_READDIR_FILLER params = {
    .buffer = buffer,
    .filler = filler
  };
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_readdir:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  if (path[0] != 0) {
    tfs_change_dir(path);
    err = check_error("op_readdir:tfs_change_dir");
    if (err) {
      return err;
    }
  }

  filler(params.buffer, ".", NULL, 0); // Current Directory
  filler(params.buffer, "..", NULL, 0); // Parent Directory

  tfs_read_dir(&params);
  err = check_error("op_readdir:tfs_read_dir");
  if (err) {
    return err;
  }

  return 0;
}

static int op_mkdir(const char *path, mode_t mode) {
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_mkdir:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  tfs_create_dir(path);
  err = check_error("op_mkdir:tfs_create_dir");
  if (err) {
    return err;
  }

  return 0;
}

static int op_unlink(const char *path) {
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_unlink:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  tfs_delete(path, TFS_DIR_ITEM_FILE);
  err = check_error("op_unlink:tfs_delete");
  if (err) {
    return err;
  }

  return 0;
}

static int op_rmdir(const char *path) {
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_rmdir:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  tfs_delete(path, TFS_DIR_ITEM_DIR);
  err = check_error("op_rmdir:tfs_delete");
  if (err) {
    return err;
  }

  return 0;
}

static int op_rename(const char *path, const char *newpath) {
  int err;
  const char *old;

  old = travel_path(path);
  if (old == NULL) {
    return check_error("op_rename:travel_path");
  }
  if (strlen(old) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  // allow rename only in the same directory
  if (strncmp(path, newpath, old - path) != 0) {
    return -EINVAL;
  }
  newpath += (old - path);
  if (strchr(newpath, '/') != NULL) {
    return -EINVAL;
  }
  if (strlen(newpath) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  tfs_rename(old, newpath);
  err = check_error("op_rename:tfs_rename");
  if (err) {
    return err;
  }

  return 0;
}

static int op_statfs(const char *path, struct statvfs *statv) {
  int err;
  uint32_t blk_free;

  memset(statv, 0, sizeof(struct statvfs));

  blk_free = drive_info.blk_count - tfs_get_used();
  err = check_error("op_statfs:tfs_get_used");
  if (err) {
    return err;
  }

  statv->f_bsize = TFS_BLOCKSIZE;
  statv->f_frsize = TFS_BLOCKSIZE;
  statv->f_blocks = drive_info.blk_count;
  statv->f_bfree = blk_free;
  statv->f_bavail = blk_free;
  statv->f_namemax = TFS_NAME_LEN;

  return 0;
}

static int op_mknod(const char *path, mode_t mode, dev_t dev) {
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_mknod:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  tfs_write_file(path, NULL, 0, 0);
  err = check_error("op_mknod:tfs_write_file");
  if (err) {
    return err;
  }

  return 0;
}

static int op_open(const char *path, struct fuse_file_info *fi) {
  int err;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_open:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  fi->fh = tfs_open(path);
  err = check_error("op_open:tfs_open");
  if (err) {
    return err;
  }

  return 0;
}

static int op_truncate(const char *path, off_t newsize) {
  int err, fh;

  path = travel_path(path);
  if (path == NULL) {
    return check_error("op_truncate:travel_path");
  }
  if (strlen(path) > TFS_NAME_LEN) {
    return -ENAMETOOLONG;
  }

  fh = tfs_open(path);
  err = check_error("op_truncate:tfs_open");
  if (err) {
    goto fail0;
  }

  tfs_trunc(fh, newsize);
  err = check_error("op_truncate:tfs_trunc");
  if (err) {
    goto fail1;
  }

fail1:
  tfs_close(fh);

fail0:
  return err;
}

static int op_ftruncate(const char *path, off_t newsize, struct fuse_file_info *fi) {
  tfs_trunc(fi->fh, newsize);
  return check_error("op_ftruncate:tfs_trunc");
}

static int op_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
  int err;
  int len;

  len = tfs_read(fi->fh, (uint8_t *) buf, size, offset);
  err = check_error("op_read:tfs_read");
  if (err) {
    return err;
  }

  return len;
}

static int op_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
  int err;
  int len;

  len = tfs_write(fi->fh, (uint8_t *) buf, size, offset);
  err = check_error("op_write:tfs_write");
  if (err) {
    return err;
  }

  return len;
}

static int op_release(const char *path, struct fuse_file_info *fi) {
  tfs_close(fi->fh);
  return check_error("op_release:tfs_close");
}

static const struct fuse_operations ops = {
  .getattr = op_getattr,
  .mknod = op_mknod,
  .mkdir = op_mkdir,
  .unlink = op_unlink,
  .rmdir = op_rmdir,
  .rename = op_rename,
  .truncate = op_truncate,
  .ftruncate = op_ftruncate,
  .open = op_open,
  .read = op_read,
  .write = op_write,
  .statfs = op_statfs,
  .release = op_release,
  .readdir = op_readdir
};

static int fuse_main_st(int argc, char *argv[], const struct fuse_operations *op, size_t op_size, void *user_data) {
  struct fuse *fuse;
  char *mountpoint;
  int multithreaded;
  int res;

  fuse = fuse_setup(argc, argv, op, op_size, &mountpoint, &multithreaded, user_data);
  if (fuse == NULL) {
    return 1;
  }

  res = fuse_loop(fuse);

  fuse_teardown(fuse, mountpoint);

  if (res == -1) {
    return 1;
  }

  return 0;
}

int main(int argc, char **argv) {
  int ret = 0;

  // See which version of fuse we're running
  fprintf(stderr, "Fuse library version %d.%d\n", FUSE_MAJOR_VERSION, FUSE_MINOR_VERSION);

  // Perform some sanity checking on the command line:  make sure
  // there are enough arguments, and that neither of the last two
  // start with a hyphen (this will break if you actually have a
  // rootpoint or mountpoint whose name starts with a hyphen, but so
  // will a zillion other programs)
  if ((argc < 3) || (argv[1][0] == '-') || (argv[2][0] == '-')) {
    fprintf(stderr, "usage:  tfs <device/image file> <mountpoint> [FUSE and mount options]\n");
    return 1;
  }

  if (drive_open(argv[1]) < 0) {
    fprintf(stderr, "Failed open device (error %d).\n", errno);
    return 1;
  }

  tfs_init();

  my_uid = getuid();

  // turn over control to fuse
  ret = fuse_main_st(argc - 1, &argv[1], &ops, sizeof(ops), NULL);

  drive_close();

  return ret;
}

void tfs_format_state(uint8_t state) {
  // NOP
}

void tfs_format_progress(uint32_t pos, uint32_t max) {
  // NOP
}

uint8_t tfs_dir_handler(TFS_READ_DIR_USERDATA filler, const TFS_DIR_ITEM *item) {
  char name[TFS_NAME_LEN + 1] =  { 0 };
  struct stat st = {
    .st_uid = my_uid,
    .st_gid = my_uid,
    .st_nlink = 1
  };

  if (item_to_stat(item, &st) == 0) {
    strncpy(name, item->name, TFS_NAME_LEN);
    filler->filler(filler->buffer, name, &st, 0);
  }

  return 1;
}

