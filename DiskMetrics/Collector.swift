import Foundation

struct Snapshot: Sendable {
    let date: Date
    let volumes: [Volume]
    let counters: DiskCounters?
    let notes: [String]
    var processes: [ProcessCounter] = []
    var uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
}

enum Collector {
    static func collect() -> Snapshot {
        let scanStarted = Date()
        var notes: [String] = []
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []
        // Identify images from macOS metadata, never from app names or volume sizes.
        var imageMounts = Set<String>()
        if let result = try? SystemCommand.run("/usr/bin/hdiutil", ["info", "-plist"], timeout: 2),
           result.status == 0, !result.timedOut,
           let plist = try? PropertyListSerialization.propertyList(from: result.data, format: nil),
           let root = plist as? [String: Any], let images = root["images"] as? [[String: Any]] {
            for image in images {
                for entity in image["system-entities"] as? [[String: Any]] ?? [] {
                    if let mount = entity["mount-point"] as? String { imageMounts.insert(mount) }
                }
            }
        } else { notes.append("Disk-image identification unavailable; unidentified volumes remain visible.") }
        var volumes: [Volume] = []
        for url in urls {
            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                guard let total = values.volumeTotalCapacity, total > 0,
                      let free = values.volumeAvailableCapacity else { continue }
                let format = values.volumeLocalizedFormatDescription ?? "unknown"
                volumes.append(Volume(name: values.volumeName ?? url.lastPathComponent,
                                      path: url.path, format: format,
                                      total: Int64(total), free: Int64(free), isDiskImage: imageMounts.contains(url.path)))
            } catch { notes.append("Cannot read \(url.path): \(error.localizedDescription)") }
        }
        var counters: DiskCounters?
        do {
            let data = try runRegistry()
            let parsed = try DiskCounters.parse(data)
            if parsed.devices > 0 { counters = parsed }
            else { notes.append("Backing-device counters unavailable on this hardware.") }
        } catch { notes.append("Device counters unavailable: \(error.localizedDescription)") }
        let activity = ProcessActivity.collect()
        notes.append(activity.note)
        return Snapshot(date: scanStarted, volumes: volumes.sorted { $0.path < $1.path }, counters: counters, notes: notes, processes: activity.records)
    }

    private static func runRegistry() throws -> Data {
        let result = try SystemCommand.run("/usr/sbin/ioreg", ["-a", "-r", "-c", "IOBlockStorageDriver"], timeout: 5)
        guard result.status == 0, !result.timedOut else {
            throw NSError(domain: "ioreg", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: result.report])
        }
        return result.data
    }

    static func demo(tick: Int) -> Snapshot {
        let used = min(Int64(99_000_000_000), 76_000_000_000 + Int64(tick) * 600_000_000)
        return Snapshot(date: Date(), volumes: [
            Volume(name: "AI Datasets (simulated)", path: "/demo/datasets", format: "apfs", total: 100_000_000_000, free: 100_000_000_000 - used),
            Volume(name: "Team Share (simulated)", path: "/demo/nfs", format: "nfs", total: 500_000_000_000, free: 310_000_000_000)
        ], counters: DiskCounters(read: Double(tick) * 240_000_000, written: Double(tick) * 600_000_000, devices: 1), notes: ["SIMULATED DATA: no disk writes or network operations are performed."])
    }
}
