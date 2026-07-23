import Foundation
import IOKit
import IOKit.pwr_mgt
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "PowerAssertion")

public struct PowerAssertion {
    private var assertionID: IOPMAssertionID = 0
    public let name: String
    public let type: String

    public init(
        name: String,
        type: String = kIOPMAssertionTypePreventUserIdleSystemSleep as String
    ) {
        self.name = name
        self.type = type
    }

    public var isActive: Bool {
        assertionID != 0
    }

    @discardableResult
    public mutating func create() -> Bool {
        let assertionName = name
        guard !isActive else {
            logger.warning("Assertion '\(assertionName)' already active")
            return true
        }
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            let id = assertionID
            logger.info("Created power assertion '\(assertionName)' (id: \(id))")
            return true
        }
        logger.error("Failed to create power assertion '\(assertionName)': \(result)")
        return false
    }

    @discardableResult
    public mutating func release() -> Bool {
        let assertionName = name
        guard isActive else {
            logger.warning("Assertion '\(assertionName)' not active, nothing to release")
            return true
        }
        let id = assertionID
        let result = IOPMAssertionRelease(assertionID)
        assertionID = 0
        if result == kIOReturnSuccess {
            logger.info("Released power assertion '\(assertionName)' (id: \(id))")
            return true
        }
        logger.error("Failed to release power assertion '\(assertionName)': \(result)")
        return false
    }
}
