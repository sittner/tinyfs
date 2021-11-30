#ifndef DRIVE_H
#define DRIVE_H

#include "filesys.h"

int drive_open(const char *dev);
int drive_close(void);

#endif
