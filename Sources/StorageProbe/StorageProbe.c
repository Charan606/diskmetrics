#include "StorageProbe.h"
#include <libproc.h>
#include <sys/resource.h>
#include <sys/proc_info.h>
#include <stdlib.h>
#include <string.h>

int vg_process_records(VGProcessRecord *output, int capacity, int *denied) {
    if (!output || capacity <= 0 || !denied) return -1;
    *denied = 0;
    int bytes = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (bytes <= 0) return -1;
    bytes += 1024 * (int)sizeof(pid_t);
    pid_t *pids = calloc(1, (size_t)bytes);
    if (!pids) return -1;
    int actual = proc_listpids(PROC_ALL_PIDS, 0, pids, bytes);
    if (actual <= 0) { free(pids); return -1; }
    if (actual > bytes) actual = bytes;
    int count = 0;
    for (int i = 0; i < actual / (int)sizeof(pid_t); i++) {
        if (pids[i] <= 0) continue;
        if (count >= capacity) { (*denied)++; continue; }
        struct proc_bsdinfo bsd = {0};
        struct rusage_info_v2 usage = {0};
        if (proc_pidinfo(pids[i], PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) != sizeof(bsd) ||
            proc_pid_rusage(pids[i], RUSAGE_INFO_V2, (rusage_info_t *)&usage) != 0) {
            (*denied)++;
            continue;
        }
        VGProcessRecord *record = &output[count++];
        memset(record, 0, sizeof(*record));
        record->pid = pids[i];
        record->uid = bsd.pbi_uid;
        record->start = usage.ri_proc_start_abstime;
        record->read_bytes = usage.ri_diskio_bytesread;
        record->write_bytes = usage.ri_diskio_byteswritten;
        proc_name(pids[i], record->name, sizeof(record->name));
        record->name[sizeof(record->name) - 1] = '\0';
    }
    free(pids);
    return count;
}
