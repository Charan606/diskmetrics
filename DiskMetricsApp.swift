import SwiftUI
import Charts

@main
struct DiskMetricsApp: App {
    @StateObject private var monitor = Monitor()
    var body: some Scene {
        MenuBarExtra {
            QuickPanel(monitor: monitor)
        } label: {
            Image(systemName: monitor.warning ? "externaldrive.badge.exclamationmark" : "externaldrive.fill")
        }.menuBarExtraStyle(.window)
        Window("DiskMetrics", id: "dashboard") {
            Dashboard(monitor: monitor).frame(minWidth: 780, minHeight: 620)
        }.defaultSize(width: 1000, height: 800)
    }
}

func rateText(_ gb: Double) -> String {
    if gb >= 1 { return String(format: "%.2f GB/s", gb) }
    if gb >= 0.001 { return String(format: "%.1f MB/s", gb * 1_000) }
    if gb > 0 { return String(format: "%.1f KB/s", gb * 1_000_000) }
    return "0 KB/s"
}

struct QuickPanel: View {
    @ObservedObject var monitor: Monitor
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DiskMetrics").font(.title2.bold())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(monitor.healthSummary(at: context.date)).font(.callout)
            }
            if monitor.demo { Text("SIMULATED DEMO").foregroundStyle(.orange).bold() }
            if let disk = monitor.visibleVolumes.first {
                Text("\(disk.name): \(bytes(disk.free)) free").font(.headline)
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(monitor.isFresh(at: context.date) && monitor.hasRates
                     ? "Read \(rateText(monitor.readRate)) • Write \(rateText(monitor.writeRate))"
                     : "Waiting for current disk activity…").font(.caption.monospacedDigit())
            }
            Button("Open dashboard") {
                openWindow(id: "dashboard")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }.buttonStyle(.borderedProminent).tint(.teal)
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }.padding(20).frame(width: 350)
    }
}

struct Dashboard: View {
    @ObservedObject var monitor: Monitor
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                health
                activity
                volumes
                applications
                StorageDetails(monitor: monitor)
                alerts
                settings
            }.padding(28)
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            Image(systemName: "externaldrive.fill").font(.largeTitle).foregroundStyle(.teal)
            VStack(alignment: .leading) {
                Text("DiskMetrics").font(.largeTitle.bold())
                Text(monitor.demo ? "SIMULATED DEMO — not your Mac's measurements" : "Your Mac's storage, at a glance")
                    .foregroundStyle(monitor.demo ? Color.orange : Color.secondary)
            }
            Spacer()
            Button("Save report") { monitor.export() }
        }
    }

    private var health: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage health").font(.title2.bold())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(monitor.healthSummary(at: context.date)).font(.headline)
            }
            if let report = monitor.diagnosticReport, !monitor.demo {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(report.sections.compactMap(\.health)) { item in
                        DiskHealthCard(health: item, checked: report.date)
                    }
                }
            }
            HStack {
                Text("Hardware readings refresh after each scan, about once a minute.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(monitor.diagnosticsBusy ? "Checking…" : "Refresh health") { Task { await monitor.refreshDiagnostics() } }
                    .disabled(monitor.diagnosticsBusy || monitor.demo)
            }
        }
    }

    private var activity: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Disk activity now").font(.title2.bold())
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(monitor.freshnessLabel(at: context.date)).font(.caption)
                            .foregroundStyle(monitor.isFresh(at: context.date) ? Color.secondary : Color.orange)
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let available = monitor.isFresh(at: context.date) && monitor.hasRates
                    HStack(spacing: 60) {
                        speed("READ", value: available ? rateText(monitor.readRate) : "Unavailable", color: .teal)
                        speed("WRITE", value: available ? rateText(monitor.writeRate) : "Unavailable", color: .orange)
                        Spacer()
                    }
                }
                Chart(monitor.rates) { point in
                    LineMark(x: .value("Time", point.date), y: .value("GB/s", point.read))
                        .foregroundStyle(by: .value("Direction", "Read"))
                    LineMark(x: .value("Time", point.date), y: .value("GB/s", point.write))
                        .foregroundStyle(by: .value("Direction", "Write"))
                }.chartForegroundStyleScale(["Read": Color.teal, "Write": Color.orange])
                    .chartYAxisLabel("GB/s").frame(height: 130)
                Text("Measured device-counter changes, normally sampled about every 2 seconds. Zero means no measured activity. Chart shows recent history across backing devices, not an individual volume or NFS share.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private func speed(_ title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
        }
    }

    private var volumes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage space").font(.title2.bold())
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(monitor.visibleVolumes) { volume in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(volume.name).font(.headline); Spacer(); Text(volume.format).font(.caption).foregroundStyle(.secondary) }
                            Text("\(bytes(volume.free)) free").font(.title2.bold()).monospacedDigit()
                            ProgressView(value: min(1, max(0, volume.fraction))).tint(volume.fraction * 100 >= monitor.threshold ? .orange : .teal)
                            Text("\(bytes(volume.used)) used of \(bytes(volume.total)) • \(Int(volume.fraction * 100))% used").font(.caption)
                            if let label = volume.auxiliaryLabel { Text(label).font(.caption).foregroundStyle(.secondary) } else { Text(monitor.forecast(volume)).font(.caption).foregroundStyle(.secondary) }
                            Text(volume.path).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Capacity: \(monitor.freshnessLabel(at: context.date)). APFS volumes can share space; their totals should not be added together.")
                    .font(.caption).foregroundStyle(monitor.isFresh(at: context.date) ? Color.secondary : Color.orange)
            }
        }
    }

    private var applications: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Applications using storage").font(.title2.bold())
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if !monitor.isFresh(at: context.date) {
                        Text("Current application activity unavailable.").foregroundStyle(.secondary)
                    } else if monitor.processRates.isEmpty {
                        Text("Waiting for accessible application counters.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(monitor.processRates.prefix(10))) { process in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(process.name).font(.headline)
                                    Text("Account \(process.uid) • PID \(process.pid)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("↓ \(rateText(process.readGBs))").foregroundStyle(.teal).frame(width: 130, alignment: .trailing)
                                Text("↑ \(rateText(process.writeGBs))").foregroundStyle(.orange).frame(width: 130, alignment: .trailing)
                            }.monospacedDigit()
                            Divider()
                        }
                    }
                }
                Text("Top 10 accessible processes by observed disk activity. Account numbers identify users; these readings do not cover every process or attribute traffic to a particular volume.").font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }

    private var alerts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alerts").font(.title2.bold())
            if monitor.incidents.isEmpty { Text("No alerts recorded.").foregroundStyle(.secondary) }
            ForEach(monitor.incidents) { incident in
                VStack(alignment: .leading, spacing: 4) {
                    Text(incident.volume).font(.headline)
                    Text(incident.message).font(.callout)
                    Text(incident.date.formatted()).font(.caption).foregroundStyle(.secondary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var settings: some View {
        GroupBox("Preferences") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show disk images and temporary/system volumes", isOn: $monitor.showSystemVolumes)
                HStack { Text("Capacity alert: \(Int(monitor.threshold))%"); Slider(value: $monitor.threshold, in: 50...98, step: 1) }
                HStack { Text(String(format: "High-write alert: %.2f GB/s", monitor.burstLimit)); Slider(value: $monitor.burstLimit, in: 0.05...3, step: 0.05) }
                Text("High-write alerts require five samples and flag activity to investigate, not malicious intent.").font(.caption).foregroundStyle(.secondary)
                Button("Enable Mac notifications") { monitor.enableNotifications() }
                Text(monitor.notificationStatus).font(.caption).foregroundStyle(.secondary)
                ForEach(monitor.notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                if !monitor.exportStatus.isEmpty { Text(monitor.exportStatus).font(.caption) }
            }.padding(10)
        }
    }
}
