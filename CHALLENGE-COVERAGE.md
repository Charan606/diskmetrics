# Challenge coverage — honest submission checklist

The source implements the following capabilities. The expanded version must still be compiled and tested on the team Mac; implementation is not hardware validation.

| Challenge area | Delivered implementation | Remaining limit / verification |
| --- | --- | --- |
| Filesystem health | Mount observation, capacity alerts, on-demand Apple filesystem verification | No automatic repair; verification may need privileges or time out |
| Backing storage health | S.M.A.R.T. plus optional smartmontools temperature, NVMe wear/spare/error counters and alerts | Requires installed smartmontools and device access for detailed fields; new adapter not yet hardware-tested |
| I/O GB/s | Aggregate device chart, accessible process rates, and opt-in local/NFS filesystem-path read/write probe | Probe reads may be cached; no continuous per-APFS-volume or NFS byte throughput |
| Capacity | Mounted storage capacity and growth forecast | Shared APFS containers must not be added together |
| Per-user quotas | Named-user native quota report | OS/filesystem/server must expose and authorize access; no quota enforcement |
| APFS limits | Container mapping, volume quota and reserve metadata | These are not per-user quotas; missing fields are labeled |
| Administrator display | Compact menu panel, single scrolling dashboard, one-sentence health assessment, visible process and report sections | Long raw reports favor completeness over chart polish; latest UI needs Mac verification |
| Alerts and reporting | Capacity, disappeared mounts, failing SMART, sustained writes; notifications; saved alerts; JSON export | Heavy writers are investigation leads, not proof of malicious intent |
| APFS | Live capacity, native metadata, verification | Expanded features need validation on the target Mac |
| NFS | Mounted capacity, mount settings, client RPC stats, local server user activity | Needs a real NFS share for validation; no remote-server attribution |
| pNFS | Explicit unsupported/unvalidated status | Not implemented; requires suitable client/server capabilities and integration work |
| Open source and builds | MIT license, Swift package, Makefile, checks and CI | Team must publish the repository |
| Demo | Live app and isolated simulated capacity scenario | Team must record and submit a short video |
| Future work | README roadmap | Present concrete limits rather than claiming full coverage |

Do not claim that all challenge bullets are fully solved. The remaining engineering gaps are exact per-filesystem throughput, pNFS, and robust cross-server quota/user attribution. The challenge asks teams to explore these areas; demonstrating supported capabilities accurately is stronger than presenting fabricated readings.
