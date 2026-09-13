import SwiftUI

struct DiskHealthCard: View {
    let health: DiskHealth
    let checked: Date
    private var color: Color { health.failing ? .red : (health.verified ? .green : .secondary) }
    private var symbol: String { health.failing ? "exclamationmark.triangle.fill" : (health.verified ? "checkmark.shield.fill" : "questionmark.circle") }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(health.headline, systemImage: symbol).font(.headline).foregroundStyle(color)
            Text("\(health.name) • \(health.device)").font(.caption).foregroundStyle(.secondary)
            Text(health.explanation).font(.callout)
            Divider()
            if let detail = health.detail {
                SSDMeasurements(detail: detail)
            }
            Text(health.detailStatus).font(.caption).foregroundStyle(.secondary)
            Text("Filesystem integrity: use the separate check in Storage details").font(.caption)
            Text("Source: macOS S.M.A.R.T. • Last scan: \(checked.formatted())")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25)))
    }
}

struct SSDMeasurements: View {
    let detail: SSDDetail
    private func percent(_ value: Double?) -> String { value.map { String(format: "%.0f%%", $0) } ?? "Not reported" }
    private func count(_ value: UInt64?) -> String { value.map { String($0) } ?? "Not reported" }
    private func terabytes(_ value: Double?) -> String { value.map { String(format: "%.2f TB", $0 / 1e12) } ?? "Not reported" }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SSD health measurements").font(.subheadline.bold())
            Text("Temperature: " + (detail.temperature.map { String(format: "%.0f °C", $0) } ?? "Not reported"))
            Text("Estimated endurance consumed: " + percent(detail.usedPercent))
            Text("Spare capacity: " + percent(detail.sparePercent) + " • Device minimum: " + percent(detail.spareThreshold))
            Text("Media/data-integrity errors: " + count(detail.mediaErrors))
            Text("Critical warning bits: " + count(detail.criticalWarning))
            Text("Lifetime reads: " + terabytes(detail.bytesRead) + " • Writes: " + terabytes(detail.bytesWritten))
            Text("Power-on hours: " + count(detail.powerOnHours) + " • Unsafe shutdowns: " + count(detail.unsafeShutdowns))
            Text("Endurance is the manufacturer's estimate of wear consumed, not a guaranteed remaining lifespan. Error and shutdown counts are cumulative.")
                .foregroundStyle(.secondary)
        }.font(.caption).monospacedDigit()
    }
}

struct StorageDetails: View {
    @ObservedObject var monitor: Monitor
    @State private var volumeToCheck: Volume?
    @State private var confirmVerification = false
    @State private var selectedReport: DiagnosticSection?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage help").font(.title2.bold())
            Text("Check a drive, test a folder, or save information to share with your administrator.")
                .foregroundStyle(.secondary)
            if monitor.demo {
                Text("These tools use real storage. Reopen the app normally to use them.").foregroundStyle(.orange)
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Check for file-system problems", systemImage: "checkmark.shield").font(.headline)
                        Text("Checks the disk's file organization. This is separate from the hardware health shown above.").font(.callout).foregroundStyle(.secondary)
                        ForEach(monitor.visibleVolumes.filter { $0.format.lowercased().contains("apfs") }) { volume in
                            HStack {
                                Text(volume.name)
                                Spacer()
                                Button(monitor.verifying ? "Checking…" : "Check this drive") {
                                    volumeToCheck = volume; confirmVerification = true
                                }.disabled(monitor.verifying)
                            }
                        }
                        Text(monitor.verifySummary).font(.callout)
                        Button("View check result") {
                            selectedReport = DiagnosticSection(title: "Drive check result", source: "Apple disk verification", text: monitor.verifyStatus)
                        }.disabled(monitor.verifying)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("How fast is this folder?", systemImage: "speedometer").font(.headline)
                        Text("Choose a folder on this Mac or shared storage. A small temporary test file is written, read, and removed.").font(.callout).foregroundStyle(.secondary)
                        Button(monitor.probeBusy ? "Testing…" : "Choose a folder to test") { monitor.chooseProbeFolder() }.disabled(monitor.probeBusy)
                        Text(monitor.probeStatus.components(separatedBy: "\n").prefix(4).joined(separator: "\n")).font(.callout).textSelection(.enabled)
                        Text("This is a one-time test. Recently read data may come from memory, so it can look faster than the disk itself.").font(.caption).foregroundStyle(.secondary)
                        Button("View full test result") {
                            selectedReport = DiagnosticSection(title: "Folder speed test", source: "DiskMetrics application I/O test", text: monitor.probeStatus)
                        }.disabled(monitor.probeBusy)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Storage limits and shared folders", systemImage: "person.2").font(.headline)
                        Text("These are mainly for workplaces that share storage or limit how much space each person can use.").font(.callout).foregroundStyle(.secondary)
                        HStack {
                            TextField("Mac account name", text: $monitor.quotaUser).textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                            Button(monitor.diagnosticsBusy ? "Checking…" : "Check account and sharing") { Task { await monitor.refreshDiagnostics() } }.disabled(monitor.diagnosticsBusy)
                        }
                        if let report = monitor.diagnosticReport {
                            ForEach(report.sections.filter { $0.health == nil }) { section in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friendlyTitle(section)).font(.headline)
                                        Text(friendlyExplanation(section)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("View report") { selectedReport = section }
                                }.padding(.vertical, 6)
                                Divider()
                            }
                            Text("Last checked: \(report.date.formatted())").font(.caption).foregroundStyle(.secondary)
                        } else { Text("Waiting for account and sharing reports.").foregroundStyle(.secondary) }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("Need help from someone else?").font(.headline)
                        Text("Save a report of readings and alerts. It can include account IDs and shared-folder addresses.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Save support report") { monitor.export() }
                }.padding(.vertical, 8)
            }
        }
        .sheet(item: $selectedReport) { section in
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text(friendlyTitle(section)).font(.title2.bold()); Spacer(); Button("Done") { selectedReport = nil } }
                Text("Technical details for troubleshooting. Missing or denied readings do not mean the disk is healthy or that storage is unlimited.").font(.callout).foregroundStyle(.secondary)
                ScrollView {
                    Text(section.text).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Source: \(section.source)").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(width: 680, height: 500)
        }
        .alert("Check this drive?", isPresented: $confirmVerification) {
            Button("Cancel", role: .cancel) {}
            Button("Run check") { if let volumeToCheck { Task { await monitor.verify(volumeToCheck) } } }
        } message: {
            Text("Save active work first. The check may briefly slow disk activity and can take up to two minutes. It does not repair or erase data.")
        }
    }

    private func friendlyTitle(_ section: DiagnosticSection) -> String {
        if section.title.hasPrefix("User quota:") { return "This person's storage allowance" }
        if section.title.hasPrefix("APFS") { return "How this Mac divides its storage" }
        if section.title == "NFS mounts and negotiated options" { return "Shared-folder connections" }
        if section.title == "NFS client operations and RPC health" { return "Shared-folder connection activity" }
        if section.title == "NFS server user activity" { return "People using folders shared by this Mac" }
        return section.title
    }

    private func friendlyExplanation(_ section: DiagnosticSection) -> String {
        if section.text.contains("Command returned status") || section.text.contains("Unavailable:") || section.text.contains("Timed out;") {
            return "A result could not be confirmed. The report explains whether access or support may be missing."
        }
        if section.text.contains("No records returned.") { return "No records were returned. The feature may not be configured or supported." }
        if section.title.hasPrefix("User quota:") { return "Checks for a space limit set by an administrator. A home Mac may not have one." }
        if section.title.hasPrefix("APFS") { return "Shows storage areas and any limits. Several areas may share the same free space." }
        if section.title == "NFS mounts and negotiated options" { return "Checks connections to folders stored on another computer." }
        if section.title == "NFS client operations and RPC health" { return "Reports network-storage requests and retries, where available." }
        if section.title == "NFS server user activity" { return "Applies only if this Mac provides an NFS share to other people." }
        return "Additional information is available in the report."
    }
}
