# DiskMetrics 0.1 — HackWesTex preview

A native Mac menu-bar app for storage capacity, device activity, reported disk health, and administrator alerts.

Download **DiskMetrics-macOS.zip** below, extract it, move DiskMetrics.app to Applications, open it, and click **Open dashboard** in its menu-bar panel. Source archives are for developers.

## Requirements

- Apple Silicon Mac for the arm64 build produced by our team.
- macOS 13 or later is the code's deployment target. Add your actually tested macOS version here before publishing.
- Optional smartmontools installation for supported-device detailed SSD metrics.

## Included

Live device throughput and capacity with freshness labels; basic SMART status; optional detailed SSD metrics; accessible process activity; capacity/heavy-write/hardware alerts; saved history and JSON reports; on-demand filesystem verification and a temporary-file folder speed test; native quota and NFS diagnostic reports when supported.

## Preview limitations

This build is ad-hoc signed, not Apple-notarized. macOS may require explicit approval to open it. See RELEASE-GUIDE.md for Apple's guidance. Continuous per-volume throughput and pNFS are not implemented. Process visibility, quotas, detailed health and NFS diagnostics depend on permissions and storage support. Heavy activity is not a malicious-user verdict. Immediate speed-test reads may come from cache.

## Validation

Before publishing, replace this paragraph with the exact test count/output, Mac model/macOS version, and scenarios your team actually verified. Do not present expected tests as executed tests.
