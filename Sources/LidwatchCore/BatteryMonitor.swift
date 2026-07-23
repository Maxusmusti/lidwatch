import Foundation
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "BatteryMonitor")

public enum BatteryStatus: Sendable, Equatable {
    case normal(level: Int)
    case warning(level: Int)
    case critical(level: Int)
    case onAC

    public static let warningThreshold = 20
    public static let criticalThreshold = 10
}

public protocol BatteryReading: Sendable {
    var batteryLevel: Int { get }
    var isOnACPower: Bool { get }
}

public struct LiveBatteryReader: BatteryReading {
    private let checker: LiveSystemChecker

    public init() {
        self.checker = LiveSystemChecker()
    }

    public var batteryLevel: Int { checker.batteryLevel }
    public var isOnACPower: Bool { checker.isOnACPower }
}

public struct BatteryMonitor {
    private let reader: BatteryReading
    public let checkInterval: TimeInterval
    public var onWarning: ((BatteryStatus) -> Void)?

    public init(
        reader: BatteryReading = LiveBatteryReader(),
        checkInterval: TimeInterval = 60
    ) {
        self.reader = reader
        self.checkInterval = checkInterval
    }

    public func checkBattery() -> BatteryStatus {
        if reader.isOnACPower {
            return .onAC
        }

        let level = reader.batteryLevel
        if level <= BatteryStatus.criticalThreshold {
            logger.critical("Battery critical: \(level)%")
            return .critical(level: level)
        } else if level <= BatteryStatus.warningThreshold {
            logger.warning("Battery low: \(level)%")
            return .warning(level: level)
        }
        logger.debug("Battery level: \(level)%")
        return .normal(level: level)
    }

    public func printStatus() {
        let status = checkBattery()
        switch status {
        case .onAC:
            print("  Battery: On AC power")
        case .normal(let level):
            print("  Battery: \(level)%")
        case .warning(let level):
            print("  ⚠ Battery: \(level)% — consider connecting power")
        case .critical(let level):
            print("  ⚠ Battery: \(level)% — CONNECT POWER NOW")
        }
    }
}
