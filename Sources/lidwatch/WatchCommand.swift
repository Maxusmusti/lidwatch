import ArgumentParser
import Foundation
import LidwatchCore
import os

private let logger = Logger(subsystem: "com.lidwatch.cli", category: "Watch")

private var _watchLidCloseActive = false

struct Watch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Watch for agent processes and prevent sleep while active"
    )

    @Option(name: .shortAndLong, help: "Poll interval in seconds")
    var interval: Int = 5

    @Option(name: .shortAndLong, help: "Battery check interval in seconds")
    var batteryInterval: Int = 60

    @Flag(name: .long, help: "Enable lid-close prevention via pmset disablesleep (requires sudo)")
    var lidClose: Bool = false

    @Option(name: .long, help: "Max duration in hours for lid-close prevention (default: 4)")
    var maxHours: Int = 4

    func run() throws {
        logger.info("Starting watch mode (poll: \(interval)s, battery: \(batteryInterval)s, lidClose: \(lidClose))")
        let detector = ProcessDetector()
        var assertion = PowerAssertion(name: "lidwatch-watch")
        let battery = BatteryMonitor(checkInterval: TimeInterval(batteryInterval))
        let lidCloseManager = LidCloseManager()
        let maxDuration = TimeInterval(maxHours * 3600)
        var lastBatteryCheck = Date.distantPast
        var wasActive = false
        var lidCloseActive = false
        var lidCloseEnabledAt: Date?

        print("Watching for agent processes (poll every \(interval)s)...")
        if lidClose {
            print("Lid-close prevention: ENABLED (will use sudo pmset disablesleep)")
            print("Max duration: \(maxHours) hours")
        }
        print("Press Ctrl+C to stop.")
        print()

        signal(SIGINT) { _ in
            if _watchLidCloseActive {
                print("\nRestoring sleep settings...")
                _restoreSleepSettings()
            }
            print("\nStopping watch mode...")
            Darwin.exit(0)
        }
        signal(SIGTERM) { _ in
            if _watchLidCloseActive {
                _restoreSleepSettings()
            }
            Darwin.exit(0)
        }

        while true {
            let agents = detector.detect()
            let now = Date()

            if !agents.isEmpty {
                if !assertion.isActive {
                    assertion.create()
                    let names = agents.map(\.name).joined(separator: ", ")
                    print("[\(timestamp())] Agents detected: \(names) — sleep prevention ON")
                    logger.info("Assertion created for agents: \(names)")

                    if lidClose && !lidCloseActive {
                        do {
                            try lidCloseManager.enable(useSudo: true)
                            if lidCloseManager.isEnabled {
                                lidCloseActive = true
                                _watchLidCloseActive = true
                                lidCloseEnabledAt = Date()
                                print("[\(timestamp())] \u{2713} Lid-close prevention is ON \u{2014} safe to close your lid")
                            } else {
                                print("[\(timestamp())] ERROR: pmset disablesleep command succeeded but state did not change")
                            }
                        } catch {
                            print("[\(timestamp())] WARNING: Failed to enable lid-close prevention: \(error.localizedDescription)")
                        }
                    }
                }
                wasActive = true

                if now.timeIntervalSince(lastBatteryCheck) >= battery.checkInterval {
                    let status = battery.checkBattery()
                    lastBatteryCheck = now
                    switch status {
                    case .critical(let level):
                        print("[\(timestamp())] CRITICAL: Battery at \(level)% — connect power immediately!")
                        if lidCloseActive {
                            disableLidClose(lidCloseManager, &lidCloseActive, &lidCloseEnabledAt,
                                          reason: "low battery")
                        }
                    case .warning(let level):
                        print("[\(timestamp())] WARNING: Battery at \(level)% — consider connecting power")
                        if lidCloseActive && lidCloseManager.shouldAutoDisable(
                            batteryLevel: level, isOnAC: false) {
                            disableLidClose(lidCloseManager, &lidCloseActive, &lidCloseEnabledAt,
                                          reason: "battery below \(LidCloseManager.lowBatteryThreshold)%")
                        }
                    default:
                        break
                    }
                }

                if lidCloseActive, let since = lidCloseEnabledAt,
                   lidCloseManager.shouldAutoDisable(enabledSince: since, maxDuration: maxDuration) {
                    disableLidClose(lidCloseManager, &lidCloseActive, &lidCloseEnabledAt,
                                  reason: "max duration of \(maxHours) hours reached")
                }
            } else if assertion.isActive {
                assertion.release()
                print("[\(timestamp())] No agents detected — sleep prevention OFF")
                logger.info("Assertion released — all agents exited")

                if lidCloseActive {
                    disableLidClose(lidCloseManager, &lidCloseActive, &lidCloseEnabledAt,
                                  reason: "all agents exited")
                }
                wasActive = false
            } else if wasActive {
                wasActive = false
            }

            Thread.sleep(forTimeInterval: TimeInterval(interval))
        }
    }
}

private func disableLidClose(_ manager: LidCloseManager,
                             _ active: inout Bool,
                             _ enabledAt: inout Date?,
                             reason: String) {
    do {
        try manager.disable(useSudo: true)
        active = false
        _watchLidCloseActive = false
        enabledAt = nil
        print("[\(timestamp())] Lid-close prevention DISABLED (\(reason))")
    } catch {
        print("[\(timestamp())] WARNING: Failed to disable lid-close prevention: \(error.localizedDescription)")
    }
}

private func _restoreSleepSettings() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    process.arguments = ["pmset", "-a", "disablesleep", "0"]
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try? process.run()
    process.waitUntilExit()
    _watchLidCloseActive = false
}

private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}
