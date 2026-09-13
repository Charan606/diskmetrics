import XCTest
@testable import DiskMetrics

final class MetricsTests: XCTestCase {
    func testForecastUsesCapacityGrowth() {
        let start = Date(timeIntervalSince1970: 0)
        let samples = [0, 10, 20].map { CapacitySample(time: start.addingTimeInterval(Double($0)), used: Int64($0) * 1_000_000) }
        XCTAssertEqual(CapacityForecast.secondsUntilFull(samples: samples, free: 60_000_000)!, 60, accuracy: 0.001)
    }
    func testNoForecastForShrinkingOrShortHistory() {
        let start = Date()
        XCTAssertNil(CapacityForecast.secondsUntilFull(samples: [CapacitySample(time: start, used: 100)], free: 500))
        let samples = [0, 10, 20].map { CapacitySample(time: start.addingTimeInterval(Double($0)), used: 100_000_000 - Int64($0) * 1_000_000) }
        XCTAssertNil(CapacityForecast.secondsUntilFull(samples: samples, free: 500))
    }
    func testRegistryCountersAndMissingSupport() throws {
        let fixture: [[String: Any]] = [["Statistics": ["Bytes (Read)": 1234, "Bytes (Write)": 5678]]]
        let data = try PropertyListSerialization.data(fromPropertyList: fixture, format: .xml, options: 0)
        let result = try DiskCounters.parse(data)
        XCTAssertEqual(result.devices, 1)
        XCTAssertEqual(result.read, 1234)
        XCTAssertEqual(result.written, 5678)
        let empty = try PropertyListSerialization.data(fromPropertyList: [["Other": 1]], format: .xml, options: 0)
        XCTAssertEqual(try DiskCounters.parse(empty).devices, 0)
    }
}
