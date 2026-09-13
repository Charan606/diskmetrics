#ifndef VOLUME_GUARD_STORAGE_PROBE_H
#define VOLUME_GUARD_STORAGE_PROBE_H
#include <stdint.h>
typedef struct {
    int32_t pid;
    uint32_t uid;
    uint64_t start;
    uint64_t read_bytes;
    uint64_t write_bytes;
    char name[256];
} VGProcessRecord;
// Returns accessible records. denied includes exited and inaccessible processes.
int vg_process_records(VGProcessRecord *output, int capacity, int *denied);
#endif
