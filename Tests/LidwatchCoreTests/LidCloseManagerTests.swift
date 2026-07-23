import Foundation
import Testing

@testable import LidwatchCore

final class TrackingCommandRunner: CommandRunning, @unchecked Sendable {
    private(set) var capturedCalls: [(executablePath: String, arguments: [String])] = []
    private let results: [(status: Int32, output: String)]
    private var callIndex = 0

    init(results: [(status: Int32, output: String)] = [(status: 0, output: "")]) {
        self.results = results
    }

    func run(executablePath: String, arguments: [String]) throws -> (status: Int32, output: String) {
        capturedCalls.append((executablePath: executablePath, arguments: arguments))
        let idx = min(callIndex, results.count - 1)
        callIndex += 1
        return results[idx]
    }

    func runInteractive(executablePath: String, arguments: [String]) throws -> Int32 {
        capturedCalls.append((executablePath: executablePath, arguments: arguments))
        let idx = min(callIndex, results.count - 1)
        callIndex += 1
        return results[idx].status
    }
}

@Suite("LidCloseManager")
struct LidCloseManagerTests {
    @Test func isEnabledWhenSleepDisabledIsOne() {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: " SleepDisabled\t\t1\n"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(manager.isEnabled)
    }

    @Test func isDisabledWhenSleepDisabledIsZero() {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: " SleepDisabled\t\t0\n"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(!manager.isEnabled)
    }

    @Test func isDisabledWhenNoSleepDisabledInOutput() {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: "System-wide power settings:\n Currently in use:\n standbydelaysec 0\n"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(!manager.isEnabled)
    }

    @Test func isDisabledWhenCommandFails() {
        let runner = TrackingCommandRunner(results: [
            (status: 1, output: "error"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(!manager.isEnabled)
    }

    @Test func enableUsesOsascriptByDefault() throws {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: ""),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        try manager.enable()
        #expect(runner.capturedCalls.count == 1)
        #expect(runner.capturedCalls[0].executablePath == "/usr/bin/osascript")
        #expect(runner.capturedCalls[0].arguments.contains("-e"))
        let script = runner.capturedCalls[0].arguments.last ?? ""
        #expect(script.contains("disablesleep 1"))
        #expect(script.contains("administrator privileges"))
    }

    @Test func enableUsesSudoWhenRequested() throws {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: ""),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        try manager.enable(useSudo: true)
        #expect(runner.capturedCalls.count == 1)
        #expect(runner.capturedCalls[0].executablePath == "/usr/bin/sudo")
        #expect(runner.capturedCalls[0].arguments.contains("disablesleep"))
    }

    @Test func enableThrowsOnAuthCancelled() {
        let runner = TrackingCommandRunner(results: [
            (status: 1, output: "User canceled (-128)"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(throws: LidCloseError.authenticationCancelled) {
            try manager.enable()
        }
    }

    @Test func enableThrowsOnCommandFailure() {
        let runner = TrackingCommandRunner(results: [
            (status: 1, output: "permission denied"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(throws: LidCloseError.self) {
            try manager.enable()
        }
    }

    @Test func disableUsesOsascriptByDefault() throws {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: ""),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        try manager.disable()
        #expect(runner.capturedCalls.count == 1)
        let script = runner.capturedCalls[0].arguments.last ?? ""
        #expect(script.contains("disablesleep 0"))
    }

    @Test func disableUsesSudoWhenRequested() throws {
        let runner = TrackingCommandRunner(results: [
            (status: 0, output: ""),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        try manager.disable(useSudo: true)
        #expect(runner.capturedCalls[0].executablePath == "/usr/bin/sudo")
    }

    @Test func disableThrowsOnAuthCancelled() {
        let runner = TrackingCommandRunner(results: [
            (status: 1, output: "User canceled"),
        ])
        let manager = LidCloseManager(commandRunner: runner)
        #expect(throws: LidCloseError.authenticationCancelled) {
            try manager.disable()
        }
    }

    @Test func shouldAutoDisableOnLowBattery() {
        let manager = LidCloseManager()
        #expect(manager.shouldAutoDisable(batteryLevel: 15, isOnAC: false))
        #expect(manager.shouldAutoDisable(batteryLevel: 5, isOnAC: false))
        #expect(!manager.shouldAutoDisable(batteryLevel: 25, isOnAC: false))
        #expect(!manager.shouldAutoDisable(batteryLevel: 15, isOnAC: true))
        #expect(!manager.shouldAutoDisable(batteryLevel: 80, isOnAC: false))
    }

    @Test func shouldAutoDisableOnMaxDuration() {
        let manager = LidCloseManager()
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 3600)
        #expect(manager.shouldAutoDisable(enabledSince: fiveHoursAgo))

        let oneHourAgo = Date().addingTimeInterval(-1 * 3600)
        #expect(!manager.shouldAutoDisable(enabledSince: oneHourAgo))
    }

    @Test func shouldAutoDisableWithCustomMaxDuration() {
        let manager = LidCloseManager()
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        #expect(manager.shouldAutoDisable(enabledSince: twoHoursAgo, maxDuration: 1 * 3600))
        #expect(!manager.shouldAutoDisable(enabledSince: twoHoursAgo, maxDuration: 3 * 3600))
    }

    @Test func defaultMaxDurationIsFourHours() {
        #expect(LidCloseManager.defaultMaxDuration == 4 * 60 * 60)
    }

    @Test func lowBatteryThresholdIsTwenty() {
        #expect(LidCloseManager.lowBatteryThreshold == 20)
    }

    @Test func lidCloseErrorDescriptions() {
        let cmdError = LidCloseError.commandFailed("test error")
        #expect(cmdError.localizedDescription.contains("test error"))

        let authError = LidCloseError.authenticationCancelled
        #expect(authError.localizedDescription.contains("cancelled"))
    }
}
