MKTFS_TARGET := mktfs
MKTFS_SRCS := mktfs.c drive.c err_handler.c ../filesys.c
MKTFS_HEADERS := drive.h err_handler.h filesys_conf.h ../filesys.h
MKTFS_OBJS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(MKTFS_SRCS)))

TFS_TARGET := tfs
TFS_SRCS := tfs_fuse.c drive.c err_handler.c ../filesys.c
TFS_HEADERS := drive.h err_handler.h filesys_conf.h ../filesys.h
TFS_OBJS := $(patsubst ../%,%,$(patsubst %.c,%.o,$(TFS_SRCS)))

CC = gcc
CFLAGS = -Wall -I. -I.. -D_FILE_OFFSET_BITS=64 -DFUSE_USE_VERSION=26
LFLAGS =

all: $(MKTFS_TARGET) $(TFS_TARGET)

$(MKTFS_TARGET): $(MKTFS_OBJS)
	$(CC) -o $@ $(MKTFS_OBJS)

$(TFS_TARGET): $(TFS_OBJS)
	$(CC) -o $@ $(TFS_OBJS) -lfuse

%.o: ../%.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.c $(HEADERS)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(MKTFS_TARGET) $(MKTFS_OBJS)
	rm -f $(TFS_TARGET) $(TFS_OBJS)

.PHONY: all clean

