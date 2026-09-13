import Foundation
import Darwin

struct CommandOutput: Sendable {
    let data: Data
    let status: Int32
    let timedOut: Bool
    var text: String { String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
    var report: String {
        if timedOut { return "Timed out; no conclusion can be drawn.\n" + text }
        if status != 0 { return "Command returned status \(status). Data may be unavailable or require permission.\n" + text }
        return text.isEmpty ? "No records returned. This does not prove support or a healthy state." : text
    }
}

enum SystemCommand {
    // No shell interpolation, passwords, or automatic privilege escalation.
    // File-backed output avoids pipe deadlocks; each child has a deadline.
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 8) throws -> CommandOutput {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diskmetrics-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil,
                                            attributes: [.posixPermissions: 0o600]) else {
            throw NSError(domain: "DiskMetrics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create command output file"])
        }
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        let timedOut = process.isRunning
        if timedOut {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning { _ = Darwin.kill(process.processIdentifier, SIGKILL) }
        }
        // Never block indefinitely waiting for a process stuck in kernel I/O.
        let status: Int32 = process.isRunning ? -1 : process.terminationStatus
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        let data = try reader.read(upToCount: 2_000_000) ?? Data()
        return CommandOutput(data: data, status: status, timedOut: timedOut)
    }
}

struct DiskHealth: Identifiable, Codable, Sendable {
    var id: String { device }
    let device: String
    let name: String
    let smartStatus: String
    var detail: SSDDetail? = nil
    var detailStatus: String = "Detailed health has not been collected."
    var normalizedStatus: String { smartStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    var verified: Bool { normalizedStatus == "verified" }
    var failing: Bool { normalizedStatus == "failing" || detail?.passed == false || (detail?.criticalWarning ?? 0) > 0 }
    var headline: String {
        if failing { return "Disk reports a hardware failure warning" }
        if verified { return "Basic disk health check passed" }
        return "Disk health unavailable"
    }
    var explanation: String {
        if failing { return "A hardware health source reports a failure or critical warning. Back up important data and investigate this drive." }
        if verified { return "macOS reports S.M.A.R.T. Verified. No failure warning is reported by this basic check; this is not a complete diagnosis." }
        return "This drive did not return a recognized pass/fail result. Unknown does not mean healthy."
    }
}

struct SSDDetail: Codable, Sendable {
    let passed: Bool?
    let temperature: Double?
    let usedPercent: Double?
    let sparePercent: Double?
    let spareThreshold: Double?
    let mediaErrors: UInt64?
    let criticalWarning: UInt64?
    let powerOnHours: UInt64?
    let unsafeShutdowns: UInt64?
    let bytesRead: Double?
    let bytesWritten: Double?

    static func parse(_ data: Data) throws -> SSDDetail {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "smartctl", code: 1)
        }
        let command = root["smartctl"] as? [String: Any]
        let status = (command?["exit_status"] as? NSNumber)?.intValue ?? 0
        // smartctl uses a bitmask: health-failure bits are valid measurements;
        // command/device/read errors (low three bits) are not a clean sample.
        guard status & 7 == 0 else {
            throw NSError(domain: "smartctl", code: status, userInfo: [NSLocalizedDescriptionKey: "Device access or health-log read failed (status \(status)). Permissions or device support may be required."])
        }
        let nvme = root["nvme_smart_health_information_log"] as? [String: Any] ?? [:]
        let overall = (root["smart_status"] as? [String: Any])?["passed"] as? Bool
        let temperature = ((root["temperature"] as? [String: Any])?["current"] as? NSNumber)?.doubleValue
            ?? (nvme["temperature"] as? NSNumber)?.doubleValue
        guard overall != nil || temperature != nil || !nvme.isEmpty else {
            throw NSError(domain: "smartctl", code: 2, userInfo: [NSLocalizedDescriptionKey: "No supported health measurements returned."])
        }
        func number(_ key: String) -> Double? { (nvme[key] as? NSNumber)?.doubleValue }
        func count(_ key: String) -> UInt64? { (nvme[key] as? NSNumber)?.uint64Value }
        return SSDDetail(passed: overall, temperature: temperature,
            usedPercent: number("percentage_used"), sparePercent: number("available_spare"), spareThreshold: number("available_spare_threshold"),
            mediaErrors: count("media_errors"), criticalWarning: count("critical_warning"), powerOnHours: count("power_on_hours"),
            unsafeShutdowns: count("unsafe_shutdowns"), bytesRead: number("data_units_read").map { $0 * 512_000 },
            bytesWritten: number("data_units_written").map { $0 * 512_000 })
    }
}

enum DetailedHealth {
    static func collect(device: String) -> (SSDDetail?, String) {
        let candidates = ["/opt/homebrew/sbin/smartctl", "/opt/homebrew/bin/smartctl", "/usr/local/sbin/smartctl", "/usr/local/bin/smartctl"]
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return (nil, "Detailed metrics require smartmontools. Install it on this Mac, then click Refresh details. Basic macOS health is still shown.")
        }
        do {
            let output = try SystemCommand.run(executable, ["-a", "-j", "/dev/" + device], timeout: 8)
            guard !output.timedOut else { return (nil, "Detailed health timed out; no result.") }
            return (try SSDDetail.parse(output.data), "Source: smartctl health log. Missing fields are not reported by the drive.")
        } catch { return (nil, "Detailed health unavailable: \(error.localizedDescription)") }
    }
}

struct DiagnosticSection: Identifiable, Codable, Sendable {
    var id: String { title }
    let title: String
    let source: String
    let text: String
    var health: DiskHealth? = nil
}

struct DiagnosticReport: Codable, Sendable {
    let date: Date
    let sections: [DiagnosticSection]
    let hardwareWarnings: [String]
}

enum Diagnostics {
    static func collect(user: String) -> DiagnosticReport {
        let scanStarted = Date()
        var sections: [DiagnosticSection] = []
        var warnings: [String] = []
        do {
            let listing = try SystemCommand.run("/usr/sbin/diskutil", ["list", "-plist", "physical"])
            if listing.status == 0, !listing.timedOut,
               let root = try PropertyListSerialization.propertyList(from: listing.data, format: nil) as? [String: Any],
               let devices = root["WholeDisks"] as? [String], !devices.isEmpty {
                for device in devices.prefix(12) {
                    let output = try SystemCommand.run("/usr/sbin/diskutil", ["info", "-plist", device], timeout: 5)
                    if output.status == 0, !output.timedOut,
                       let info = try? PropertyListSerialization.propertyList(from: output.data, format: nil) as? [String: Any] {
                        let smart = info["SMARTStatus"] as? String ?? "Unavailable (not reported by this device)"
                        let name = info["MediaName"] as? String ?? device
                        let (detail, detailStatus) = DetailedHealth.collect(device: device)
                        let health = DiskHealth(device: device, name: name, smartStatus: smart, detail: detail, detailStatus: detailStatus)
                        if health.failing { warnings.append("\(device) reports a hardware failure or critical warning. Back up data and investigate the device.") }
                        if let errors = detail?.mediaErrors, errors > 0 { warnings.append("\(device) reports \(errors) lifetime media/data-integrity errors. Check whether the count is increasing; this is a cumulative count.") }
                        if let used = detail?.usedPercent, used >= 100 { warnings.append("\(device) reports \(used)% of estimated endurance consumed. Review replacement planning; this is not a failure-date prediction.") }
                        if let spare = detail?.sparePercent, let minimum = detail?.spareThreshold, spare < minimum { warnings.append("\(device) reports spare capacity below its device threshold.") }
                        let size = (info["TotalSize"] as? NSNumber)?.int64Value ?? 0
                        let protocolName = info["BusProtocol"] as? String ?? "Unavailable"
                        sections.append(DiagnosticSection(title: "Hardware: \(device)", source: "diskutil info -plist \(device)",
                            text: "\(name)\nCapacity: \(bytes(size))\nConnection: \(protocolName)\nS.M.A.R.T.: \(smart)\nA verified S.M.A.R.T. status is not a filesystem integrity check or a guarantee against failure.", health: health))
                    } else {
                        sections.append(DiagnosticSection(title: "Hardware: \(device)", source: "diskutil info", text: output.report,
                            health: DiskHealth(device: device, name: device, smartStatus: "Unavailable")))
                    }
                }
                if devices.count > 12 { sections.append(DiagnosticSection(title: "Device scan limit", source: "DiskMetrics", text: "Only the first 12 physical devices were queried in this scan.")) }
            } else { sections.append(DiagnosticSection(title: "Hardware health", source: "diskutil list -plist physical", text: listing.report)) }
        } catch { sections.append(DiagnosticSection(title: "Hardware health", source: "diskutil", text: error.localizedDescription)) }

        do {
            let result = try SystemCommand.run("/usr/sbin/diskutil", ["apfs", "list", "-plist"])
            if result.status == 0, !result.timedOut,
               let root = try PropertyListSerialization.propertyList(from: result.data, format: nil) as? [String: Any],
               let containers = root["Containers"] as? [[String: Any]] {
                var lines: [String] = []
                for container in containers {
                    let reference = container["ContainerReference"] as? String ?? "Unknown container"
                    lines.append("Container: \(reference)")
                    if let stores = container["PhysicalStores"] as? [[String: Any]] {
                        lines.append("Backing stores: " + stores.compactMap { $0["DeviceIdentifier"] as? String }.joined(separator: ", "))
                    }
                    for (key, label) in [("CapacityCeiling", "Container capacity"), ("CapacityFree", "Container free")] {
                        if let number = container[key] as? NSNumber { lines.append("\(label): \(bytes(number.int64Value))") }
                    }
                    for volume in container["Volumes"] as? [[String: Any]] ?? [] {
                        let name = volume["Name"] as? String ?? "Unnamed"
                        let id = volume["DeviceIdentifier"] as? String ?? "Unknown device"
                        lines.append("\n  \(name) (\(id))")
                        for (key, label) in [("CapacityInUse", "Used"), ("CapacityQuota", "Volume quota"), ("CapacityReserve", "Volume reserve")] {
                            if let number = volume[key] as? NSNumber {
                                let value = number.int64Value == 0 && key != "CapacityInUse" ? "Not configured" : bytes(number.int64Value)
                                lines.append("  \(label): \(value)")
                            } else { lines.append("  \(label): Not reported") }
                        }
                    }
                    lines.append("")
                }
                sections.append(DiagnosticSection(title: "APFS containers and volume limits", source: "diskutil apfs list -plist",
                    text: "Volume limits are different from per-user quotas. Shared container space must not be counted twice.\n\n" + (lines.isEmpty ? "No APFS containers reported." : lines.joined(separator: "\n"))))
            } else { sections.append(DiagnosticSection(title: "APFS containers and volume limits", source: "diskutil apfs list -plist", text: result.report)) }
        } catch { sections.append(DiagnosticSection(title: "APFS containers and volume limits", source: "diskutil", text: error.localizedDescription)) }

        let validUser = !user.isEmpty && !user.hasPrefix("-") && user.utf8.count <= 256 && !user.contains(where: { $0.isWhitespace || $0.isNewline })
        if validUser {
            sections.append(commandSection("User quota: \(user)", "/usr/bin/quota", ["-v", "-u", user],
                explanation: "Native quota report for the named user. Limits, usage, and grace periods are shown when the filesystem/server provides them. Other users may require privileges. No output does not establish that quotas are supported; DiskMetrics does not enforce quotas."))
        } else { sections.append(DiagnosticSection(title: "User quota", source: "quota", text: "Enter a valid short account name, such as the name shown by whoami.")) }
        sections.append(commandSection("NFS mounts and negotiated options", "/usr/sbin/nfsstat", ["-m"],
            explanation: "Shared-storage mount details reported by macOS. No pNFS capability is inferred from an NFS mount or protocol version."))
        sections.append(commandSection("NFS client operations and RPC health", "/usr/sbin/nfsstat", ["-c"],
            explanation: "Cumulative client counters, including retries/timeouts where available. Operation counts are not byte throughput. Compare successive reports when investigating a slow share."))
        sections.append(commandSection("NFS server user activity", "/usr/sbin/nfsstat", ["-u", "-n", "net"],
            explanation: "Only activity served by THIS Mac, if its NFS server is active and exposes records. This is not the user list of a remote server. Activity alone does not identify malicious intent."))
        return DiagnosticReport(date: scanStarted, sections: sections, hardwareWarnings: warnings)
    }

    private static func commandSection(_ title: String, _ executable: String, _ args: [String], explanation: String) -> DiagnosticSection {
        let output: String
        do { output = try SystemCommand.run(executable, args).report }
        catch { output = "Unavailable: \(error.localizedDescription)" }
        return DiagnosticSection(title: title, source: executable + " " + args.joined(separator: " "), text: explanation + "\n\n" + output)
    }
}
