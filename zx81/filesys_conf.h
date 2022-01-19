#ifndef _FILESYS_CONF_H
#define _FILESYS_CONF_H

#undef TFS_EXTENDED_API
#undef TFS_READ_DIR_USERDATA

#define TFS_FILENAME_CMP(ref, cmp) filename_cmp(ref, cmp)
uint8_t filename_cmp(const char *ref, const char *cmp);

#endif

