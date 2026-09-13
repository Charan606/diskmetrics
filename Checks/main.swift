import Foundation

var failures = 0
var checks = 0
func check(_ condition: Bool, _ name: String) {
    checks += 1
    if condition { print("PASS: \(name)") }
    else { failures += 1; print("FAIL: \(name)") }
}

let start = Date(timeIntervalSince1970: 0)
let growing = [0, 10, 20].map {
    CapacitySample(time: start.addingTimeInterval(Double($0)), used: Int64($0) * 1_000_000)
}
let forecast = CapacityForecast.secondsUntilFull(samples: growing, free: 60_000_000)
check(forecast.map { abs($0 - 60) < 0.001 } ?? false, "Forecast uses net capacity growth")
check(CapacityForecast.secondsUntilFull(samples: [], free: 500) == nil, "Empty history has no forecast")
check(CapacityForecast.secondsUntilFull(samples: Array(growing.prefix(2)), free: 500) == nil, "Short history has no forecast")
let shrinking = [0, 10, 20].map {
    CapacitySample(time: start.addingTimeInterval(Double($0)), used: 100_000_000 - Int64($0) * 1_000_000)
}
check(CapacityForecast.secondsUntilFull(samples: shrinking, free: 500) == nil, "Shrinking usage has no forecast")
let steady = [0, 10, 20].map {
    CapacitySample(time: start.addingTimeInterval(Double($0)), used: 100_000_000)
}
check(CapacityForecast.secondsUntilFull(samples: steady, free: 500) == nil, "Stable usage has no forecast")

do {
    let fixture: [[String: Any]] = [["Statistics": ["Bytes (Read)": 1234, "Bytes (Write)": 5678]]]
    let data = try PropertyListSerialization.data(fromPropertyList: fixture, format: .xml, options: 0)
    let result = try DiskCounters.parse(data)
    check(result.devices == 1 && result.read == 1234 && result.written == 5678, "Device counters are decoded correctly")
    let nested: [[String: Any]] = [["IORegistryEntryChildren": fixture]]
    let nestedData = try PropertyListSerialization.data(fromPropertyList: nested, format: .xml, options: 0)
    check(try DiskCounters.parse(nestedData).devices == 1, "Nested device is counted once")
    let empty = try PropertyListSerialization.data(fromPropertyList: [["Other": 1]], format: .xml, options: 0)
    check(try DiskCounters.parse(empty).devices == 0, "Missing counters remain unavailable")
} catch {
    check(false, "Counter fixture parsing: \(error)")
}
do {
    _ = try DiskCounters.parse(Data("invalid property list".utf8))
    check(false, "Malformed registry data is rejected")
} catch {
    check(true, "Malformed registry data is rejected")
}

let before = ProcessCounter(pid: 12, uid: 501, start: 10, name: "Writer", read: 0, written: 0)
let after = ProcessCounter(pid: 12, uid: 501, start: 10, name: "Writer", read: 2_000_000_000, written: 4_000_000_000)
let rates = ProcessRate.calculate(old: [before], new: [after], elapsed: 2)
check(rates.first?.readGBs == 1 && rates.first?.writeGBs == 2, "Process byte deltas use elapsed time")
let reused = ProcessCounter(pid: 12, uid: 501, start: 20, name: "Different process", read: 9_000_000_000, written: 9_000_000_000)
check(ProcessRate.calculate(old: [before], new: [reused], elapsed: 2).isEmpty, "Reused process ID is not attributed to previous process")
check(ProcessRate.calculate(old: [after], new: [before], elapsed: 2).isEmpty, "Regressed process counters are discarded")
check(ProcessRate.calculate(old: [before], new: [after], elapsed: 0).isEmpty, "Zero sample interval is rejected")
do {
    let literal = try SystemCommand.run("/bin/echo", ["literal; $(no-shell)"])
    check(literal.status == 0 && literal.text == "literal; $(no-shell)", "Command arguments are passed literally without a shell")
    let timeout = try SystemCommand.run("/bin/sleep", ["2"], timeout: 0.05)
    check(timeout.timedOut, "Slow command has a bounded timeout")
    let failure = try SystemCommand.run("/usr/bin/false", [])
    check(failure.status != 0 && failure.report.contains("status"), "Failed command cannot appear successful")
} catch { check(false, "Command runner fixtures: \(error)") }

let verifiedHealth = DiskHealth(device: "disk0", name: "Test", smartStatus: " Verified\n")
check(verifiedHealth.verified && !verifiedHealth.failing, "Verified SMART maps only to basic-check pass")
let failedHealth = DiskHealth(device: "disk0", name: "Test", smartStatus: "Failing")
check(failedHealth.failing && !failedHealth.verified, "Failing SMART produces a hardware warning")
let missingHealth = DiskHealth(device: "disk0", name: "Test", smartStatus: "Not Supported")
check(!missingHealth.verified && !missingHealth.failing && missingHealth.headline == "Disk health unavailable", "Unsupported health never appears healthy")

do {
    let fixture: [String: Any] = ["smartctl": ["exit_status": 0], "smart_status": ["passed": true],
        "temperature": ["current": 42], "nvme_smart_health_information_log": [
            "percentage_used": 103, "available_spare": 99, "media_errors": 0,
            "critical_warning": 0, "data_units_written": 2]]
    let detail = try SSDDetail.parse(JSONSerialization.data(withJSONObject: fixture))
    check(detail.temperature == 42 && detail.usedPercent == 103 && detail.bytesWritten == 1_024_000, "NVMe wear is not clamped and data units convert correctly")
    check(detail.powerOnHours == nil && detail.unsafeShutdowns == nil, "Missing health measurements stay unknown")
    let failure: [String: Any] = ["smartctl": ["exit_status": 8], "smart_status": ["passed": false]]
    let failing = try SSDDetail.parse(JSONSerialization.data(withJSONObject: failure))
    check(failing.passed == false, "SMART health-failure bit preserves the failure measurement")
} catch { check(false, "Detailed SMART fixtures: \(error)") }
do {
    _ = try SSDDetail.parse(JSONSerialization.data(withJSONObject: ["smartctl": ["exit_status": 2], "smart_status": ["passed": true]]))
    check(false, "Failed device access cannot produce a healthy result")
} catch { check(true, "Failed device access cannot produce a healthy result") }

check(!ReadingFreshness.isFresh(sample: nil, now: start, limit: 10), "Missing measurement is not live")
check(ReadingFreshness.isFresh(sample: start, now: start.addingTimeInterval(2), limit: 10), "Recent measurement is live")
check(!ReadingFreshness.isFresh(sample: start, now: start.addingTimeInterval(11), limit: 10), "Stale measurement is not live")
check(!ReadingFreshness.isFresh(sample: start.addingTimeInterval(2), now: start, limit: 10), "Clock rollback cannot mark a future measurement live")

print("\(checks - failures)/\(checks) checks passed.")
if failures > 0 { exit(1) }
