import AppKit
import Foundation
import UserNotifications

struct RatePoint: Identifiable {
    let id = UUID()
    let date: Date
    let read: Double
    let write: Double
}

@MainActor
final class Monitor: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var rates: [RatePoint] = []
    @Published var incidents: [Incident] = []
    @Published var notes: [String] = []
    @Published var demo = false
    @Published var threshold = 85.0
    @Published var updated: Date?
    @Published var collecting = false
    @Published var exportStatus = ""
    @Published var showSystemVolumes = false
    @Published var diagnosticReport: DiagnosticReport?
    @Published var diagnosticsBusy = false
    @Published var quotaUser = NSUserName()
    @Published var notificationStatus = "Desktop notifications are off."
    @Published var verifyStatus = "No filesystem check has been run."
    @Published var verifySummary = "Not checked yet. Run this only when you want to check how files are organized on the disk."
    @Published var verifying = false
    @Published var probeBusy = false
    @Published var probeStatus = "No filesystem performance probe has been run."
    @Published var burstLimit = 0.5
    @Published var processRates: [ProcessRate] = []
    private var userBurstSamples: [UInt32: Int] = [:]
    private var burstSamples = 0
    private var notificationsEnabled = false
    private var diagnosticWorker: Task<Void, Never>?
    private var samples: [String: [CapacitySample]] = [:]
    private var alerted: Set<String> = []
    private var previous: Snapshot?
    private var worker: Task<Void, Never>?
    private var tick = 0

    init() {
        demo = ProcessInfo.processInfo.arguments.contains("--demo")
        if !demo {
            do { try LegacyMigration.restoreAlertsIfNeeded() }
            catch { exportStatus = "Previous alert history could not be copied: \(error.localizedDescription)" }
        }
        if !demo, let data = try? Data(contentsOf: Self.alertURL),
           let saved = try? JSONDecoder().decode([Incident].self, from: data) { incidents = Array(saved.prefix(200)) }
        worker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        diagnosticWorker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshDiagnostics()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private static var alertURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiskMetrics/alerts.json")
    }

    var visibleVolumes: [Volume] {
        showSystemVolumes ? volumes : volumes.filter { !$0.isAuxiliary }
    }

    func isFresh(at date: Date) -> Bool {
        ReadingFreshness.isFresh(sample: updated, now: date, limit: 10)
    }

    func freshnessLabel(at date: Date) -> String {
        guard let updated else { return "Waiting for first measurement" }
        let age = max(0, Int(date.timeIntervalSince(updated)))
        return isFresh(at: date) ? "Measured \(age)s ago" : "Stale — last measured \(age)s ago"
    }

    var healthSummary: String { healthSummary(at: Date()) }

    func healthSummary(at date: Date) -> String {
        if demo { return "Demo mode — no real health assessment" }
        guard let report = diagnosticReport else { return "Checking storage health…" }
        guard ReadingFreshness.isFresh(sample: report.date, now: date, limit: 180) else { return "Health reading is old — refresh to check again" }
        let health = report.sections.compactMap(\.health)
        if !report.hardwareWarnings.isEmpty { return "Attention needed — a disk reports a hardware or endurance warning" }
        if health.isEmpty { return "Storage health unavailable — no drive health reading" }
        if health.contains(where: { !$0.verified && $0.detail?.passed != true }) { return "Storage health incomplete — some drives cannot be checked" }
        return "No hardware failure warning reported — filesystem integrity is checked separately"
    }

    func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] allowed, error in
            Task { @MainActor in
                self?.notificationsEnabled = allowed
                self?.notificationStatus = error?.localizedDescription ?? (allowed ? "Desktop notifications enabled." : "Notifications were not allowed. In-app alerts remain available.")
            }
        }
    }

    func refreshDiagnostics() async {
        guard !diagnosticsBusy, !demo else { return }
        diagnosticsBusy = true
        defer { diagnosticsBusy = false }
        let user = quotaUser
        let report = await Task.detached(priority: .utility) { Diagnostics.collect(user: user) }.value
        guard !demo else { return }
        diagnosticReport = report
        for message in report.hardwareWarnings {
            if alerted.insert("hardware:" + message).inserted { addIncident("Hardware", message) }
        }
    }

    func verify(_ volume: Volume) async {
        guard !verifying, !demo else { return }
        verifying = true
        defer { verifying = false }
        verifyStatus = "Checking \(volume.name)… this can take up to two minutes."
        verifySummary = "Checking \(volume.name)…"
        let path = volume.path
        let output = await Task.detached(priority: .utility) { () -> (String, String) in
            do {
                let result = try SystemCommand.run("/usr/sbin/diskutil", ["verifyVolume", path], timeout: 120)
                let summary = result.timedOut ? "The check took too long. Its result is unknown."
                    : (result.status == 0 ? "Check completed without a reported filesystem error."
                       : "The check did not confirm a pass. Open the result to see why.")
                return (result.report, summary)
            } catch { return ("Unable to run check: \(error.localizedDescription)", "The check could not start. Open the result for details.") }
        }.value
        verifyStatus = output.0
        verifySummary = output.1
    }

    func chooseProbeFolder() {
        guard !probeBusy, !demo else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Test this folder"
        panel.message = "Choose a folder on this Mac or shared storage. The test creates a temporary file of about 67 MB, reads it, and removes it. An unavailable shared folder can delay the test."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        probeBusy = true
        probeStatus = "Measuring application I/O in \(folder.path)…"
        Task {
            let output = await Task.detached(priority: .utility) { FilesystemProbe.measure(folder: folder) }.value
            probeStatus = output
            probeBusy = false
        }
    }

    var warning: Bool {
        volumes.contains { !$0.isAuxiliary && $0.fraction * 100 >= threshold }
            || !(diagnosticReport?.hardwareWarnings.isEmpty ?? true)
    }
    var readRate: Double { rates.last?.read ?? 0 }
    var writeRate: Double { rates.last?.write ?? 0 }
    var hasRates: Bool { previous?.counters != nil && !rates.isEmpty }

    func switchMode() {
        samples = [:]; alerted = []; previous = nil; tick = 0
        volumes = []; rates = []; incidents = []; updated = nil
        burstSamples = 0; diagnosticReport = nil
        processRates = []; userBurstSamples = [:]
        if !demo, let data = try? Data(contentsOf: Self.alertURL),
           let saved = try? JSONDecoder().decode([Incident].self, from: data) { incidents = Array(saved.prefix(200)) }
    }

    func forecast(_ volume: Volume) -> String {
        guard let seconds = CapacityForecast.secondsUntilFull(samples: samples[volume.path] ?? [], free: volume.free) else {
            return "Time to full: waiting for sustained growth"
        }
        if seconds > 86400 * 30 { return "Time to full: over 30 days at recent growth" }
        return "Time to full: ~\(max(1, Int(seconds / 60))) min at recent growth"
    }

    func refresh() async {
        guard !collecting else { return }
        collecting = true
        defer { collecting = false }
        let requestedDemo = demo
        tick += 1
        let snapshot: Snapshot
        if requestedDemo { snapshot = Collector.demo(tick: tick) }
        else { snapshot = await Task.detached(priority: .utility) { Collector.collect() }.value }
        guard requestedDemo == demo else { return }
        if let old = previous {
            processRates = ProcessRate.calculate(old: old.processes, new: snapshot.processes, elapsed: snapshot.uptime - old.uptime)
            let byUser = Dictionary(grouping: processRates, by: \.uid)
            for uid in Array(userBurstSamples.keys) where byUser[uid] == nil { userBurstSamples.removeValue(forKey: uid) }
            for (uid, processes) in byUser {
                let writes = processes.reduce(0) { $0 + $1.writeGBs }
                userBurstSamples[uid] = writes >= burstLimit ? (userBurstSamples[uid] ?? 0) + 1 : 0
                if userBurstSamples[uid] == 5 {
                    let names = processes.sorted { $0.writeGBs > $1.writeGBs }.prefix(3).map(\.name).joined(separator: ", ")
                    addIncident("Account UID \(uid)", String(format: "Observed writes %.3f GB/s across accessible processes for five samples. Top writers: %@. Investigate workload intent; this is not proof of abuse.", writes, names))
                }
            }
        }
        if let old = previous, let a = old.counters, let b = snapshot.counters {
            let elapsed = snapshot.uptime - old.uptime
            if elapsed > 0, a.devices == b.devices, b.read >= a.read, b.written >= a.written {
                rates.append(RatePoint(date: snapshot.date, read: (b.read - a.read) / elapsed / 1e9, write: (b.written - a.written) / elapsed / 1e9))
                rates = Array(rates.suffix(90))
            } else { rates = [] }
        } else { rates = [] }
        if hasRates && writeRate >= burstLimit {
            burstSamples += 1
            if burstSamples == 5 {
                addIncident("Device activity", String(format: "Sustained writes above %.2f GB/s for five samples. Investigate active workloads; this does not identify a user or prove malicious activity.", burstLimit))
            }
        } else { burstSamples = 0 }
        for volume in snapshot.volumes {
            var history = samples[volume.path] ?? []
            history.append(CapacitySample(time: snapshot.date, used: volume.used))
            samples[volume.path] = Array(history.suffix(60))
            // Internal service volumes have different capacity semantics; show them on
            // request but don't alert on them as though they were dataset volumes.
            if volume.isAuxiliary { continue }
            let key = "capacity:\(volume.path)"
            if volume.fraction * 100 >= threshold {
                if alerted.insert(key).inserted {
                    addIncident(volume.path, "Capacity \(Int(volume.fraction * 100))% exceeds \(Int(threshold))% threshold. \(bytes(volume.free)) free. Review dataset growth and available capacity.")
                }
            } else if volume.fraction * 100 < threshold - 3 { alerted.remove(key) }
        }
        let current = Set(snapshot.volumes.map(\.path))
        for volume in previous?.volumes ?? [] where !current.contains(volume.path) {
            if !volume.isAuxiliary { addIncident(volume.path, "Mount is no longer observed. Check whether it was intentionally unmounted or whether the connection failed.") }
            samples.removeValue(forKey: volume.path)
        }
        volumes = snapshot.volumes; notes = snapshot.notes
        updated = snapshot.date; previous = snapshot
    }

    private func addIncident(_ volume: String, _ message: String) {
        incidents.insert(Incident(id: UUID(), date: Date(), volume: volume, message: message), at: 0)
        incidents = Array(incidents.prefix(200))
        if !demo {
            do {
                try FileManager.default.createDirectory(at: Self.alertURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(incidents).write(to: Self.alertURL, options: .atomic)
            } catch { exportStatus = "Could not save alert history: \(error.localizedDescription)" }
        }
        if notificationsEnabled {
            let content = UNMutableNotificationContent()
            content.title = demo ? "DiskMetrics DEMO alert" : "DiskMetrics alert"
            content.body = volume + ": " + message
            content.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil), withCompletionHandler: nil)
        }
    }

    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "disk-metrics-report.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            var report: [String: Any] = [
                "generatedAt": ISO8601DateFormatter().string(from: Date()),
                "simulated": demo,
                "throughputScope": "Aggregate available backing-device counters; not per-volume or NFS throughput",
                "volumes": volumes.map { ["path": $0.path, "format": $0.format, "totalBytes": $0.total, "freeBytes": $0.free] as [String: Any] },
                "alerts": incidents.map { ["date": ISO8601DateFormatter().string(from: $0.date), "volume": $0.volume, "message": $0.message] },
                "notes": notes
            ]
            if let diagnosticReport, !demo {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                report["diagnostics"] = try JSONSerialization.jsonObject(with: encoder.encode(diagnosticReport))
            }
            if !demo { report["filesystemVerification"] = verifyStatus }
            if !demo { report["filesystemPerformanceProbe"] = probeStatus }
            report["processActivity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(processRates))
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
            exportStatus = "Report saved."
        } catch { exportStatus = "Export failed: \(error.localizedDescription)" }
    }
}
