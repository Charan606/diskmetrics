# DiskMetrics

Team submission for HackWesTex. [Original challenge brief](CHALLENGE-BRIEF.md).

**Assembly status:** awaiting our teammate's `Sources/DiskMetrics/DiskMetricsApp.swift`. The remaining project files are present. `make test` can run now; building the complete app requires that final file.


See your Mac's storage space, disk activity, and reported drive health in one simple dashboard.

Built for the TTU HackWesTex 2026 challenge. Runs locally on macOS 13 or newer.

## Download and install

**[Download DiskMetrics for Apple Silicon](https://github.com/Charan606/disk-metrics/releases/download/v0.1.0/Disk-Metrics-macOS.zip)** · [Release notes](https://github.com/Charan606/disk-metrics/releases/tag/v0.1.0)

1. Download the ZIP using the link above.
2. Double-click the ZIP to extract the app.
3. Drag the extracted app into **Applications**, then open it.
4. Click the **disk icon in the top menu bar**, then **Open dashboard**.

Requires macOS 13 or newer. This preview is not notarized by Apple, so macOS may show a security warning. The published ZIP currently uses the filename `Disk-Metrics-macOS.zip`; the project is named **DiskMetrics**.

The **Code → Download ZIP** button downloads source code. Use the download link above for the app.

### Build from source (optional)

Use these steps if you want to develop the app or build the latest source yourself.

1. [Download the source ZIP](https://github.com/Charan606/hackwestex27/archive/refs/heads/main.zip) and double-click it to extract it.
2. Open **Terminal** using Spotlight (press Command + Space and type Terminal).
3. Type `cd ` with a space, drag the extracted folder into Terminal, and press Return.
4. If you have never installed Apple's developer tools, run `xcode-select --install` and finish the installation.
5. Run these commands one at a time:

```sh
make test
make update
```

The app opens automatically. Click its **disk icon in the top menu bar**, then **Open dashboard**.

The installed app is in your home folder under `Applications/DiskMetrics.app`. Building requires Swift 5.9 or newer. If a command fails, keep its error message for troubleshooting.

## What you can see

- **Storage space:** how much space is used and how much is left.
- **Drive health:** the status reported by your drive, with unavailable information clearly marked.
- **Disk activity:** how quickly your disks are reading and writing data.
- **App activity:** which accessible apps are using the disk.
- **Alerts:** low storage and unusual sustained writing activity.
- **Storage checks and reports:** check a drive, test a folder's speed, or save a report.

Normal launches use real measurements. Simulated demonstrations are explicitly labeled. No cloud account is required, and the app does not scan your file contents.

## Update without reinstalling

Download and extract the latest source. Open Terminal in that folder as above, then run:

```sh
make test
make update
```

This replaces the installed app and keeps your saved alerts. If you use a Git clone, `make sync` fetches updates and rebuilds the app.

## What is still limited?

- The speed chart combines available physical-disk activity; it does not show a separate live speed for every shared folder.
- Network folders (NFS) and per-person storage limits need a configured server and real-world testing.
- Parallel network storage (pNFS) is not implemented.
- A passing drive health check is not a guarantee against failure. Some drives do not expose detailed health data.
- Reports can include account names and storage paths. Review them before sharing.

See the [challenge checklist](CHALLENGE-COVERAGE.md) for the full coverage and testing status.

## For the team

To create the downloadable app ZIP, run on the Mac:

```sh
make test
make package
```

Upload `dist/DiskMetrics-macOS.zip` to a GitHub Release after testing it. The build matches the Mac's architecture. Current builds are locally signed and are not notarized by Apple.

- [Publishing the app](RELEASE-GUIDE.md)
- [Updating on a Mac](UPDATING-ON-MAC.md)
- [Simple project explanation and presentation guide](PRESENTATION-GUIDE.md)
- [Challenge coverage and remaining work](CHALLENGE-COVERAGE.md)

Future work includes better network-storage measurements, clearer user storage limits, broader drive testing, and a signed, notarized download.

## License

Open source under the [MIT License](LICENSE).
