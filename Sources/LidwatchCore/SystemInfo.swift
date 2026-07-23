import CoreGraphics
import Foundation
import IOKit.ps
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "SystemInfo")

public struct SystemInfo: Sendable {
    public init() {}

    public var isAppleSilicon: Bool {
        var size: size_t = 0
        let result = sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        guard result == 0, size > 0 else { return false }
        var value: Int32 = 0
        size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return value == 1
    }

    public var chipArchitecture: String {
        isAppleSilicon ? "Apple Silicon (arm64)" : "Intel (x86_64)"
    }

    public var isOnACPower: Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sourceList = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue()
        let sources = sourceList as NSArray

        if sources.count == 0 {
            logger.debug("No power sources found — assuming desktop Mac on AC")
            return true
        }

        for i in 0..<sources.count {
            let source = sources[i] as CFTypeRef
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() else {
                continue
            }
            let info = desc as NSDictionary
            if let state = info[kIOPSPowerSourceStateKey] as? String,
               state == kIOPSACPowerValue {
                return true
            }
        }
        logger.info("Running on battery power")
        return false
    }

    public var externalDisplayCount: Int {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        let result = CGGetActiveDisplayList(16, &displayIDs, &displayCount)
        guard result == .success else {
            logger.error("Failed to get display list: \(result.rawValue)")
            return 0
        }
        let externalCount = max(0, Int(displayCount) - 1)
        logger.debug("Detected \(displayCount) displays (\(externalCount) external)")
        return externalCount
    }

    public var hasExternalDisplay: Bool {
        externalDisplayCount > 0
    }
}
