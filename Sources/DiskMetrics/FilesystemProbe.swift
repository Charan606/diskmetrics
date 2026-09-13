import Foundation
import Security

enum FilesystemProbe {
    // A small, opt-in application-level probe, not a sustained disk benchmark.
    static func measure(folder: URL) -> String {
        let file = folder.appendingPathComponent(".diskmetrics-probe-\(UUID().uuidString)")
        let manager = FileManager.default
        let blockSize = 1_048_576
        let blocks = 64
        var block = Data(count: blockSize)
        let randomStatus = block.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { return "Probe could not prepare test data." }
        guard manager.createFile(atPath: file.path, contents: nil) else { return "Cannot create a temporary probe file in this folder. Check write permissions." }
        var result: String
        do {
            let writer = try FileHandle(forWritingTo: file)
            let writeStart = ProcessInfo.processInfo.systemUptime
            do {
                for _ in 0..<blocks { try writer.write(contentsOf: block) }
                try writer.synchronize()
                try writer.close()
            } catch { try? writer.close(); throw error }
            let writeSeconds = ProcessInfo.processInfo.systemUptime - writeStart
            let reader = try FileHandle(forReadingFrom: file)
            let readStart = ProcessInfo.processInfo.systemUptime
            var readBytes = 0
            do {
                while let data = try reader.read(upToCount: blockSize), !data.isEmpty { readBytes += data.count }
                try reader.close()
            } catch { try? reader.close(); throw error }
            let readSeconds = ProcessInfo.processInfo.systemUptime - readStart
            guard readBytes == blockSize * blocks else { throw NSError(domain: "DiskMetrics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Probe read size did not match written size."]) }
            let size = Double(readBytes)
            result = String(format: "Folder: %@\n64 MiB application I/O probe\nWrite + synchronize: %.3f GB/s (%.3f seconds)\nRead immediately afterward: %.3f GB/s (%.3f seconds)\nRead may be served from cache. Synchronize does not prove durable storage across every network server or device. These are application-observed rates for this folder, not live per-volume counters or maximum disk speed.", folder.path, size / max(writeSeconds, 0.000001) / 1e9, writeSeconds, size / max(readSeconds, 0.000001) / 1e9, readSeconds)
        } catch { result = "Probe failed: \(error.localizedDescription)" }
        do { try manager.removeItem(at: file) }
        catch { result += "\nTemporary file could not be removed: \(file.path). Remove this probe file when the volume is accessible." }
        return result
    }
}
