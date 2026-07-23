import Testing

@testable import LidwatchCore

struct MockBatteryReader: BatteryReading {
    var batteryLevel: Int
    var isOnACPower: Bool
}

@Suite("BatteryMonitor")
struct BatteryMonitorTests {
    @Test func normalBattery() {
        let reader = MockBatteryReader(batteryLevel: 80, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .normal(level: 80))
    }

    @Test func warningThreshold() {
        let reader = MockBatteryReader(batteryLevel: 20, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .warning(level: 20))
    }

    @Test func criticalThreshold() {
        let reader = MockBatteryReader(batteryLevel: 10, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .critical(level: 10))
    }

    @Test func belowCritical() {
        let reader = MockBatteryReader(batteryLevel: 5, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .critical(level: 5))
    }

    @Test func onACPower() {
        let reader = MockBatteryReader(batteryLevel: 50, isOnACPower: true)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .onAC)
    }

    @Test func thresholdConstants() {
        #expect(BatteryStatus.warningThreshold == 20)
        #expect(BatteryStatus.criticalThreshold == 10)
    }

    @Test func justAboveWarning() {
        let reader = MockBatteryReader(batteryLevel: 21, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .normal(level: 21))
    }

    @Test func justAboveCritical() {
        let reader = MockBatteryReader(batteryLevel: 11, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader)
        let status = monitor.checkBattery()
        #expect(status == .warning(level: 11))
    }

    @Test func customCheckInterval() {
        let reader = MockBatteryReader(batteryLevel: 50, isOnACPower: false)
        let monitor = BatteryMonitor(reader: reader, checkInterval: 120)
        #expect(monitor.checkInterval == 120)
    }
}
