MKFS_TARGET := mkfs.tfs
MKFS_SRCS := mkfs.c drive.c err_handler.c ../filesys.c
MKFS_HEADERS := drive.h err_handler.h filesys_conf.h ../filesys.h
MKFS_OBJS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(MKFS_SRCS)))

TFS_TARGET := tfs
TFS_SRCS := tfs_fuse.c drive.c err_handler.c ../filesys.c
TFS_HEADERS := drive.h err_handler.h filesys_conf.h ../filesys.h
TFS_OBJS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(TFS_SRCS)))

CC = gcc
CFLAGS = -Wall -g -I. -I.. -D_FILE_OFFSET_BITS=64 -DFUSE_USE_VERSION=26
LFLAGS =

all: $(MKFS_TARGET) $(TFS_TARGET)

$(MKFS_TARGET): $(MKFS_OBJS)
	$(CC) -o $@ $(MKFS_OBJS)

$(TFS_TARGET): $(TFS_OBJS)
	$(CC) -o $@ $(TFS_OBJS) -lfuse

%.o: ../%.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(MKFS_TARGET) $(MKFS_OBJS)
	rm -f $(TFS_TARGET) $(TFS_OBJS)

.PHONY: all clean

