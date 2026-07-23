import CoreGraphics
import Foundation
import IOKit
import IOKit.ps
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "SafetyChecker")

public enum ReadinessLevel: String, Sendable, CustomStringConvertible {
    case ready = "ready"
    case partial = "partial"
    case notReady = "not_ready"

    public var description: String {
        switch self {
        case .ready: return "Safe to close lid"
        case .partial: return "Missing prerequisites — see details"
        case .notReady: return "Keep lid open — sleep prevention active for idle sleep only"
        }
    }
}

public struct ClamshellCheck: Sendable, CustomStringConvertible {
    public let name: String
    public let passed: Bool
    public let detail: String

    public init(name: String, passed: Bool, detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }

    public var description: String {
        let icon = passed ? "✓" : "✗"
        return "  \(icon) \(name): \(detail)"
    }
}

public struct ClamshellReport: Sendable {
    public let readiness: ReadinessLevel
    public let checks: [ClamshellCheck]
    public let isAppleSilicon: Bool

    public init(readiness: ReadinessLevel, checks: [ClamshellCheck], isAppleSilicon: Bool) {
        self.readiness = readiness
        self.checks = checks
        self.isAppleSilicon = isAppleSilicon
    }
}

public protocol SystemChecking: Sendable {
    var isAppleSilicon: Bool { get }
    var isOnACPower: Bool { get }
    var hasExternalDisplay: Bool { get }
    var hasExternalKeyboard: Bool { get }
    var hasExternalMouse: Bool { get }
    var batteryLevel: Int { get }
}

public struct LiveSystemChecker: SystemChecking {
    private let systemInfo = SystemInfo()

    public init() {}

    public var isAppleSilicon: Bool { systemInfo.isAppleSilicon }
    public var isOnACPower: Bool { systemInfo.isOnACPower }
    public var hasExternalDisplay: Bool { systemInfo.hasExternalDisplay }

    public var hasExternalKeyboard: Bool {
        hasHIDDevice(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Keyboard)
    }

    public var hasExternalMouse: Bool {
        hasHIDDevice(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Mouse)
            || hasHIDDevice(usagePage: kHIDPage_GenericDesktop, usage: kHIDUsage_GD_Pointer)
    }

    public var batteryLevel: Int {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sourceList = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        let sources = sourceList as NSArray

        for i in 0..<sources.count {
            let source = sources[i] as CFTypeRef
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() else { continue }
            let info = desc as NSDictionary
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                return capacity
            }
        }
        return 100
    }

    private func hasHIDDevice(usagePage: Int, usage: Int) -> Bool {
        let matching = IOServiceMatching("IOHIDDevice") as NSMutableDictionary
        matching[kIOHIDDeviceUsagePageKey] = usagePage
        matching[kIOHIDPrimaryUsageKey] = usage

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        var count = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            count += 1
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        // Built-in keyboard/trackpad always present — external means >1
        return count > 1
    }
}

public struct SafetyChecker {
    private let checker: SystemChecking

    public init(checker: SystemChecking = LiveSystemChecker()) {
        self.checker = checker
    }

    public func checkClamshellReadiness() -> ClamshellReport {
        let isAppleSilicon = checker.isAppleSilicon
        var checks: [ClamshellCheck] = []

        checks.append(ClamshellCheck(
            name: "Architecture",
            passed: true,
            detail: isAppleSilicon ? "Apple Silicon" : "Intel"
        ))

        let onAC = checker.isOnACPower
        checks.append(ClamshellCheck(
            name: "AC Power",
            passed: onAC,
            detail: onAC ? "Connected" : "On battery — connect power for clamshell mode"
        ))

        let hasDisplay = checker.hasExternalDisplay
        checks.append(ClamshellCheck(
            name: "External Display",
            passed: hasDisplay,
            detail: hasDisplay ? "Connected" : "None — required for clamshell mode"
        ))

        let hasKeyboard = checker.hasExternalKeyboard
        checks.append(ClamshellCheck(
            name: "External Keyboard",
            passed: hasKeyboard,
            detail: hasKeyboard ? "Connected" : "None — recommended for clamshell mode"
        ))

        let hasMouse = checker.hasExternalMouse
        checks.append(ClamshellCheck(
            name: "External Mouse/Trackpad",
            passed: hasMouse,
            detail: hasMouse ? "Connected" : "None — recommended for clamshell mode"
        ))

        let readiness: ReadinessLevel
        if isAppleSilicon {
            // Apple Silicon requires power + display at minimum
            if onAC && hasDisplay {
                readiness = .ready
            } else if onAC || hasDisplay {
                readiness = .partial
            } else {
                readiness = .notReady
            }
        } else {
            // Intel has fewer restrictions
            readiness = onAC ? .ready : .partial
        }

        logger.info("Clamshell readiness: \(readiness.rawValue)")
        return ClamshellReport(readiness: readiness, checks: checks, isAppleSilicon: isAppleSilicon)
    }
}
