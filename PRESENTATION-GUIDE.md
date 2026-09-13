# DiskMetrics: understand it, demonstrate it, explain it

## Start with this sentence

**DiskMetrics is a Mac app that helps people notice storage problems before those problems interrupt their work.**

It answers four questions: Is the drive reporting a problem? How much space remains? Which applications are using storage? What should I investigate?

It does not run an AI model. It monitors the storage used by local AI and other applications. The challenge is about infrastructure for AI, not a requirement to put a chatbot in the app.

## Why anyone needs this

Imagine a small clinic that keeps sensitive documents on its own Mac rather than uploading them to an online AI service. Its local AI workflow needs models, documents, indexes, and temporary files. Those files can grow. If storage fills up, downloads and writes can fail. If the drive reports hardware warnings, important data may be at risk. If a shared folder is unavailable, the workflow can lose access to its files.

DiskMetrics brings available Mac storage readings into one view and alerts the person running the system. It does not read patients' documents or certify healthcare compliance. The clinic is a use-case example, not a customer or a validated deployment.

## The vocabulary, without assuming IT knowledge

| Word | Meaning | Example |
| --- | --- | --- |
| Disk / SSD | The physical device that stores files when power is off | The SSD inside a MacBook |
| Filesystem | The rules and bookkeeping used to organize files | Like a library catalog that says where books are |
| Volume | A named storage area that macOS can access | Macintosh HD |
| APFS | Apple's filesystem format | The format normally used by your Mac's internal storage |
| Container | An APFS pool of space shared by volumes | Several shelves sharing the same room |
| NFS | A way to access a folder stored on another computer over a network | A team dataset folder on a server |
| pNFS | An extension for parallel access to NFS storage | Relevant to larger shared-storage environments; not implemented/validated here |
| Capacity | How much space exists or remains | 344 GB free |
| Throughput | How much data moves per second | Reading 200 MB each second |
| Read / write | Retrieve stored data / save data | Opening a dataset / saving a checkpoint |
| Quota | A configured storage allowance | An administrator limits an account to a certain amount of space |
| S.M.A.R.T. | A drive's health-reporting mechanism | A drive reports Verified, Failing, or unavailable |
| Endurance consumed | A drive manufacturer's estimate of wear used | 5% consumed is not an exact failure-date prediction |
| Process | A running program or part of one | A Python training job |
| PID / UID | A process number / an account number | Used to identify a writer without guessing its owner |
| Cache | A faster temporary copy, often held in memory | A recently written file may read back from memory |
| JSON | A structured text format used by software | Our exported report |
| Repository | The shared project history and source files | Your public GitHub project |
| Build | Convert source code into an executable app | `make app` |
| Release | A published version people can download | A ZIP containing DiskMetrics.app |

## What every part of the app means

### Storage health

The one-line overview summarizes collected hardware warnings. It does not combine unrelated signals into a made-up health score. A basic Verified reading means that source is not reporting a failure; it cannot promise that the drive will never fail. Filesystem structure is checked separately.

With smartmontools installed and readable hardware, the app can also show temperature, estimated endurance used, spare capacity, error counts, hours powered on, unsafe shutdowns, and cumulative bytes read/written. Missing values remain unavailable. A 0 media-error reading means zero was reported; unavailable is not the same as zero.

### Disk activity

The main chart reads cumulative device counters and calculates changes. If a counter increases by 400 million bytes over two seconds, the rate is 200 million bytes/second, or 0.2 decimal GB/s. Small rates are shown as MB/s or KB/s so real activity does not misleadingly round to 0.000 GB/s.

These counters describe available backing devices in aggregate. They are not exact independent readings for every APFS volume and they are not NFS network throughput. The chart contains recent history; its latest reading is timestamped. Live rate text becomes unavailable when the sample becomes stale.

### Storage space

Total minus available space gives the displayed used amount. Multiple APFS volumes can share container space, so adding their totals would double-count space. Internal service volumes are hidden by default and excluded from capacity alerts. The app does not scan every document to get these numbers.

### Time until full

The app compares used capacity across a recent window of samples. It waits for at least three samples and 20 seconds, and requires more than 1 MB of net growth. If 100 MB of extra space is consumed every second and 10 GB remains, the simple forecast is about 100 seconds. That is an estimate under the recent trend, not a promise. Deletions and workload changes can invalidate it.

Write speed is not used as a substitute for growth: overwriting an existing file can write many bytes without consuming more space.

### Applications using storage

The app samples accessible process disk counters and shows the top ten processes by observed activity. It includes process and account IDs. Some processes are inaccessible or disappear between samples. Counters are process-wide, not tied to a specific volume.

The app pairs a PID with process start time. This matters because macOS can reuse an old PID for a different process. It also rejects counter regressions and zero/invalid sample intervals.

### Storage help

**Check this drive** invokes Apple's filesystem verification command. It examines filesystem organization; it does not run a repair or erase command. It may briefly affect responsiveness. An unsuccessful command can mean lack of permission or unsupported behavior, not necessarily corruption.

**Choose a folder to test** writes a temporary 64 MiB file, synchronizes it, reads it, measures elapsed time, and removes it. This works on a writable local or mounted shared folder. Immediate reads may come from cache. It is an application-observed workload result, not proof of the physical disk's maximum speed or server durability. A disconnected network share can stall the test.

**Storage limits and shared folders** explains what each report is for. Technical output is available in a separate report window for troubleshooting. APFS volume limits differ from per-user quotas. Native per-user quotas require filesystem/server support and permission. NFS user activity describes users served by THIS Mac, not all users of another server.

### Alerts and saved reports

The app records capacity threshold crossings, disappeared mounts, reported failing hardware, certain detailed health warnings, and sustained heavy writes. Five consecutive samples above the write threshold trigger investigation alerts. Heavy writes can be perfectly legitimate; we do not label a person malicious or block their work.

Capacity alerts re-arm after usage drops three percentage points below the threshold, which reduces repeated warnings around the boundary. Up to 200 live alerts are retained in Application Support. Optional Mac notifications require permission. Reports can include account IDs, process names, volume paths, and server addresses; review them before sharing.

## How the code works

Follow this path when a judge asks about architecture:

```text
macOS / drive counters
          |
          v
Collectors read snapshots --> Monitor calculates rates and checks alerts
                                      |
                                      v
                              SwiftUI displays changes
                                      |
                                      v
                         Saved alerts / exported reports
```

**Swift** is the main programming language. **SwiftUI** builds the native interface. A small **C** component makes some low-level process APIs easier to use from Swift. No web server or cloud database is needed.

| File | Its job | What to say |
| --- | --- | --- |
| `DiskMetricsApp.swift` | Menu-bar entry, dashboard sections, chart, and freshness presentation | “This is the interface.” |
| `StorageDetails.swift` | Plain-language storage tools and technical-report windows | “It separates everyday guidance from troubleshooting output.” |
| `Monitor.swift` | Owns current state, periodic refresh, rate updates, alert decisions, notifications, exports | “This coordinates collection and presentation.” |
| `Collector.swift` | Reads mounted-volume capacity, ioreg device counters, process snapshots | “This asks macOS for measurements.” |
| `Metrics.swift` | Models, forecast calculations, process rate calculations, freshness rule | “This turns measurements into useful information.” |
| `Diagnostics.swift` | Runs bounded commands, reads disk health, smartctl JSON, quotas and NFS reports | “This gathers deeper storage reports.” |
| `ProcessActivity.swift` | Converts C process records into Swift values | “This connects low-level process data to the app.” |
| `StorageProbe.c` and its header | Uses libproc to enumerate and read accessible process counters | “The small native bridge for process attribution.” |
| `FilesystemProbe.swift` | Performs and cleans up the opt-in temporary-file speed test | “This measures a real workload in a selected folder.” |
| `Checks/main.swift` | Standalone regression checks without needing XCTest | “These test calculations, parsing, freshness and command behavior.” |
| `Package.swift` | Declares Swift targets and the C dependency | “The compiler's project map.” |
| `Makefile` | Build/test/package/update commands | “Our reproducible command-line workflow.” |
| `packaging/Info.plist` | App identity, executable, minimum OS, menu-bar behavior | “Metadata that makes the executable a Mac app.” |
| `scripts/StopApp.swift` | Requests the old app to quit during an update | “Updating does not require manual deletion.” |

The main refresh normally happens around every two seconds plus collection time. Hardware/diagnostics refresh about once a minute after a scan completes. Slower work runs off the main UI thread. Child commands use argument arrays rather than shell command strings, discard no user data, and have deadlines. Some direct filesystem calls can still stall on unavailable network storage; this is a known limitation.

`@Published` means “notify the interface when this value changes.” `@StateObject` keeps one monitor for the app. `Task` runs asynchronous work. `Codable` helps turn structured values into/from saved data. You do not need to recite syntax; understand why the components exist.

## A three-minute presentation

**0:00–0:25 — Problem.** “Local AI needs storage for models and datasets. Teams need to know when space is running out, storage is busy, or a drive reports a warning. We built DiskMetrics, a native Mac menu-bar monitor.”

**0:25–0:55 — Real readings.** Open the dashboard in normal mode. Point to the health summary, free space and timestamp. Say: “These come from this Mac. A missing measurement stays unavailable; we do not invent it.”

**0:55–1:25 — Real activity.** Run a pre-tested small folder speed test on a disposable local folder. Explain that this generates actual I/O, and cached reads can be faster than the physical disk. Show the measured result and activity chart. Do not promise a particular peak value or process visibility.

**1:25–1:55 — Alerts.** If the live disk usage is above the slider's minimum, temporarily set the capacity threshold below that usage and disclose the setting change. Otherwise, use a separate clearly labeled `--demo` launch that you rehearsed. Never fill the system disk for the demonstration. Say: “The alert is caused by crossing the configured limit.”

**1:55–2:20 — Evidence.** Save a report. Explain that it contains the observed readings and alerts, which an administrator can investigate. Show real NFS or quota output ONLY if you prepared and tested that environment.

**2:20–2:45 — Engineering.** “SwiftUI presents data, collectors read macOS sources, the monitor computes deltas and evaluates rules. A small C bridge collects accessible process activity. We keep UI work separate from collection.”

**2:45–3:00 — Scope and future.** “We provide the source, build instructions and a downloadable app. Next we want validated pNFS, continuous per-volume throughput and broader server-side quota support.” Say “downloadable app” only after publishing the release.

Record a backup video. Do not rely on installing dependencies or discovering a server during judging.

## Questions judges may ask

**Is this real-time or random data?** Normal mode reads real counters. Activity is periodically sampled, not instantaneous. Live values have freshness limits. Only an explicitly launched simulated demo uses generated samples.

**Why is this related to AI?** It monitors the storage infrastructure needed by local AI. It is not an AI inference engine and does not need one to calculate these metrics.

**Why not just use existing commands?** We use existing native sources rather than inventing replacements. The value is integrating them into an accessible interface with history, forecasts, alerts and reports. We did not write Apple's filesystem checker or smartmontools.

**How accurate is health?** It reports what the device exposes. S.M.A.R.T. is useful evidence, not a guarantee. Wear is an estimate, not an exact lifespan. Filesystem verification is a separate check.

**Can you identify malicious users?** We identify sustained observed writes and associated accessible processes/accounts. That is an investigation signal, not a verdict. A legitimate training job may be a heavy writer.

**Does it support every quota and pNFS setup?** No. Quota reports rely on native filesystem/server support and authorization. pNFS is not implemented/validated, and continuous per-volume throughput remains a gap. Do not answer yes just because an NFS report exists.

**Does it scale to petabytes?** Capacity collection uses metadata rather than reading every file, which is a useful design choice. But we have not validated petabyte-scale or large-fleet deployments. We must not claim that performance without tests.

**Why are test reads so fast?** The file was just written and can be cached. The result is application-observed speed for this workload, not a raw-media benchmark.

**Does it change or upload files?** Background monitoring does not inspect document contents. The explicit speed probe creates and removes its own temporary file. Alerts are saved locally; exported reports go to a chosen location. The app does not send reports to a service automatically.

**What did you test?** Describe only tests you actually ran. The current suite has 27 checks covering forecast behavior, process identity/rates, malformed/missing counters, command failures/timeouts, SMART interpretation, and stale readings. These do not replace hardware, NFS, UI or distribution testing.

**How does someone install it?** They download the compiled app ZIP from our GitHub release, extract it and open the app. A normal user does not compile Swift. Our current ad-hoc-signed build may require explicit macOS approval; a polished release needs Developer ID signing and notarization.

**Did AI help build it?** Yes, if asked. “We used an AI coding assistant to develop the implementation, and we built and tested it on our Mac. Here is what the components do and what we verified.” Do not claim manual authorship of code you did not write. Review event AI-tool rules separately if provided.

**What would you do with another week?** Validate a real shared-storage environment, improve server-side attribution, collect continuous per-volume metrics where available, test more hardware, and sign/notarize the public release.

## Divide the explanation among four people

1. Product speaker: problem, ordinary-user experience and live demo.
2. Collector speaker: macOS data sources, device/process distinctions and limitations.
3. Logic/testing speaker: rate formula, growth forecast, alert thresholds and test results.
4. Delivery speaker: GitHub repository, build commands, release download and future work.

Each person should make and understand a genuine contribution. Practice saying “We have not validated that yet” when appropriate. It is stronger than a claim you cannot demonstrate.

## What to do before judging

Run the current build and checks. Verify the actual app screenshot. Prepare a bounded demo folder. Install smartmontools if you intend to show detailed SSD metrics. Prepare a real NFS share if you intend to claim tested NFS support. Publish source and the built app release. Record the video. Open the public repository in a signed-out browser to confirm judges can access it.
