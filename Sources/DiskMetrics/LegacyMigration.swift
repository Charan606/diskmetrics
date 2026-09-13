import Foundation

enum LegacyMigration {
    // Compatibility only: preserve saved alerts from releases before the rename.
    static func restoreAlertsIfNeeded() throws {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = base.appendingPathComponent("VolumeGuard/alerts.json")
        let current = base.appendingPathComponent("DiskMetrics/alerts.json")
        guard !FileManager.default.fileExists(atPath: current.path),
              FileManager.default.fileExists(atPath: old.path) else { return }
        try FileManager.default.createDirectory(at: current.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: old, to: current)
    }
}
