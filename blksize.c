#include <stdint.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/fs.h>

// ...

const char* pathname="/dev/sda";
int fd=open(pathname,O_RDONLY);
if (fd==-1) {
  die("%s",strerror(errno));
}

uint64_t size;
if (ioctl(fd,BLKGETSIZE64,&size)==-1) {
  die("%s",strerror(errno));
}

close(fd);
