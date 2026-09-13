import Foundation
import StorageProbe

enum ProcessActivity {
    static func collect() -> (records: [ProcessCounter], note: String) {
        var buffer = [VGProcessRecord](repeating: VGProcessRecord(), count: 4096)
        var denied: Int32 = 0
        let count = buffer.withUnsafeMutableBufferPointer { vg_process_records($0.baseAddress, Int32($0.count), &denied) }
        guard count >= 0 else { return ([], "Process counters unavailable.") }
        let records = buffer.prefix(Int(count)).map { item -> ProcessCounter in
            var item = item
            let name = withUnsafePointer(to: &item.name) {
                $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
            }
            return ProcessCounter(pid: item.pid, uid: item.uid, start: item.start,
                                  name: name.isEmpty ? "PID \(item.pid)" : name,
                                  read: item.read_bytes, written: item.write_bytes)
        }
        return (records, "\(count) processes sampled; \(denied) inaccessible, exited, or beyond the scan limit. These are process-wide disk counters, not per-volume or network-byte counters.")
    }
}
