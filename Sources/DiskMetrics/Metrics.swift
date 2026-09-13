import Foundation

enum ReadingFreshness {
    static func isFresh(sample: Date?, now: Date, limit: TimeInterval) -> Bool {
        guard let sample else { return false }
        let elapsed = now.timeIntervalSince(sample)
        return elapsed >= 0 && elapsed <= limit
    }
}

struct ProcessCounter: Sendable {
    let pid: Int32
    let uid: UInt32
    let start: UInt64
    let name: String
    let read: UInt64
    let written: UInt64
    var identity: String { "\(pid):\(start)" }
}

struct ProcessRate: Identifiable, Codable, Sendable {
    let id: String
    let pid: Int32
    let uid: UInt32
    let name: String
    let readGBs: Double
    let writeGBs: Double
    static func calculate(old: [ProcessCounter], new: [ProcessCounter], elapsed: Double) -> [ProcessRate] {
        guard elapsed > 0 else { return [] }
        let previous = Dictionary(old.map { ($0.identity, $0) }, uniquingKeysWith: { first, _ in first })
        return new.compactMap { current -> ProcessRate? in
            guard let before = previous[current.identity], before.uid == current.uid,
                  current.read >= before.read, current.written >= before.written else { return nil }
            return ProcessRate(id: current.identity, pid: current.pid, uid: current.uid, name: current.name,
                               readGBs: Double(current.read - before.read) / elapsed / 1e9,
                               writeGBs: Double(current.written - before.written) / elapsed / 1e9)
        }.sorted { $0.readGBs + $0.writeGBs > $1.readGBs + $1.writeGBs }
    }
}

struct Volume: Identifiable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let format: String
    let total: Int64
    let free: Int64
    var isDiskImage: Bool = false
    var auxiliaryLabel: String? {
        if path.contains("/AppTranslocation/") { return "Temporary macOS app mount" }
        if path.hasPrefix("/System/Volumes/") { return "Internal macOS volume" }
        if isDiskImage { return "Disk image (may contain an installer)" }
        return nil
    }
    var isAuxiliary: Bool { auxiliaryLabel != nil }
    var used: Int64 { max(0, total - free) }
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct CapacitySample: Sendable {
    let time: Date
    let used: Int64
}

enum CapacityForecast {
    // Capacity growth, never write throughput. Require a meaningful observation window.
    static func secondsUntilFull(samples: [CapacitySample], free: Int64) -> Double? {
        guard let first = samples.first, let last = samples.last,
              samples.count >= 3 else { return nil }
        let elapsed = last.time.timeIntervalSince(first.time)
        let growth = Double(last.used - first.used)
        guard elapsed >= 20, growth > 1_000_000 else { return nil }
        return Double(max(0, free)) / (growth / elapsed)
    }
}

struct Incident: Identifiable, Codable {
    let id: UUID
    let date: Date
    let volume: String
    let message: String
}

struct DiskCounters: Sendable {
    var read: Double = 0
    var written: Double = 0
    var devices: Int = 0

    static func parse(_ data: Data) throws -> DiskCounters {
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        var result = DiskCounters()
        func visit(_ node: Any) {
            if let list = node as? [Any] { list.forEach(visit) }
            if let dict = node as? [String: Any] {
                if let stats = dict["Statistics"] as? [String: Any],
                   let read = stats["Bytes (Read)"] as? NSNumber,
                   let written = stats["Bytes (Write)"] as? NSNumber {
                    result.read += read.doubleValue
                    result.written += written.doubleValue
                    result.devices += 1
                }
                // Only registry child nodes: don't count arbitrary nested dictionaries twice.
                if let children = dict["IORegistryEntryChildren"] { visit(children) }
            }
        }
        visit(root)
        return result
    }
}

func bytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: value, countStyle: .decimal)
}
