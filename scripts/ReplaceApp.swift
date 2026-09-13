import Foundation

// Replace a generated app bundle as a whole so obsolete executables do not remain.
let manager = FileManager.default
let args = CommandLine.arguments
guard args.count == 3 else { print("Usage: ReplaceApp.swift source.app destination.app"); exit(1) }
let source = URL(fileURLWithPath: args[1]).standardizedFileURL
let destination = URL(fileURLWithPath: args[2]).standardizedFileURL
guard source.lastPathComponent == "DiskMetrics.app", destination.lastPathComponent == "DiskMetrics.app",
      source != destination, manager.fileExists(atPath: source.appendingPathComponent("Contents/MacOS/DiskMetrics").path) else {
    print("Expected a built DiskMetrics app and a distinct app destination."); exit(1)
}
let parent = destination.deletingLastPathComponent()
let staged = parent.appendingPathComponent(".disk-metrics-staged-\(UUID().uuidString).app")
let backup = parent.appendingPathComponent(".disk-metrics-backup-\(UUID().uuidString).app")
do {
    try manager.createDirectory(at: parent, withIntermediateDirectories: true)
    try manager.copyItem(at: source, to: staged)
    let exists = manager.fileExists(atPath: destination.path)
    if exists { try manager.moveItem(at: destination, to: backup) }
    do { try manager.moveItem(at: staged, to: destination) }
    catch {
        if exists { try? manager.moveItem(at: backup, to: destination) }
        throw error
    }
    if exists { try? manager.removeItem(at: backup) }
} catch { print("App replacement failed: \(error.localizedDescription)"); exit(1) }
