import Foundation
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "LidCloseManager")

public enum LidCloseError: Error, LocalizedError, Sendable, Equatable {
    case commandFailed(String)
    case authenticationCancelled
    case alreadyEnabled
    case alreadyDisabled

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let detail):
            return "pmset command failed: \(detail)"
        case .authenticationCancelled:
            return "Authentication was cancelled by the user"
        case .alreadyEnabled:
            return "Lid-close prevention is already enabled"
        case .alreadyDisabled:
            return "Lid-close prevention is already disabled"
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(executablePath: String, arguments: [String]) throws -> (status: Int32, output: String)
}

public struct SystemCommandRunner: CommandRunning {
    public init() {}

    public func run(executablePath: String, arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        return (status: process.terminationStatus, output: output + errorOutput)
    }
}

public struct LidCloseManager {
    private let commandRunner: CommandRunning
    public static let defaultMaxDuration: TimeInterval = 4 * 60 * 60
    public static let lowBatteryThreshold = 20

    public init(commandRunner: CommandRunning = SystemCommandRunner()) {
        self.commandRunner = commandRunner
    }

    public var isEnabled: Bool {
        do {
            let result = try commandRunner.run(
                executablePath: "/usr/bin/pmset",
                arguments: ["-g"]
            )
            return result.output.contains("SleepDisabled\t\t1")
        } catch {
            logger.error("Failed to check pmset state: \(error.localizedDescription)")
            return false
        }
    }

    public func enable(useSudo: Bool = false) throws {
        logger.info("Enabling lid-close sleep prevention (useSudo: \(useSudo))")

        let result: (status: Int32, output: String)
        if useSudo {
            result = try commandRunner.run(
                executablePath: "/usr/bin/sudo",
                arguments: ["pmset", "-a", "disablesleep", "1"]
            )
        } else {
            result = try commandRunner.run(
                executablePath: "/usr/bin/osascript",
                arguments: [
                    "-e",
                    "do shell script \"pmset -a disablesleep 1\" with administrator privileges",
                ]
            )
        }

        if result.status != 0 {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.contains("User canceled") || output.contains("(-128)") {
                logger.warning("User cancelled authentication for lid-close prevention")
                throw LidCloseError.authenticationCancelled
            }
            logger.error("Failed to enable lid-close prevention: \(output)")
            throw LidCloseError.commandFailed(output)
        }

        logger.info("Lid-close sleep prevention enabled")
    }

    public func disable(useSudo: Bool = false) throws {
        logger.info("Disabling lid-close sleep prevention (useSudo: \(useSudo))")

        let result: (status: Int32, output: String)
        if useSudo {
            result = try commandRunner.run(
                executablePath: "/usr/bin/sudo",
                arguments: ["pmset", "-a", "disablesleep", "0"]
            )
        } else {
            result = try commandRunner.run(
                executablePath: "/usr/bin/osascript",
                arguments: [
                    "-e",
                    "do shell script \"pmset -a disablesleep 0\" with administrator privileges",
                ]
            )
        }

        if result.status != 0 {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if output.contains("User canceled") || output.contains("(-128)") {
                logger.warning("User cancelled authentication for lid-close disable")
                throw LidCloseError.authenticationCancelled
            }
            logger.error("Failed to disable lid-close prevention: \(output)")
            throw LidCloseError.commandFailed(output)
        }

        logger.info("Lid-close sleep prevention disabled")
    }

    public func shouldAutoDisable(batteryLevel: Int, isOnAC: Bool) -> Bool {
        if !isOnAC && batteryLevel < LidCloseManager.lowBatteryThreshold {
            logger.warning("Battery below \(LidCloseManager.lowBatteryThreshold)% — should auto-disable lid-close prevention")
            return true
        }
        return false
    }

    public func shouldAutoDisable(enabledSince: Date, maxDuration: TimeInterval = LidCloseManager.defaultMaxDuration) -> Bool {
        let elapsed = Date().timeIntervalSince(enabledSince)
        if elapsed >= maxDuration {
            let hours = Int(elapsed / 3600)
            logger.warning("Lid-close prevention active for \(hours)h — exceeds max duration")
            return true
        }
        return false
    }
}
