import ArgumentParser
import Foundation
import LidwatchCore
import os

private let logger = Logger(subsystem: "com.lidwatch.cli", category: "Watch")

struct Watch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Watch for agent processes and prevent sleep while active"
    )

    @Option(name: .shortAndLong, help: "Poll interval in seconds")
    var interval: Int = 5

    @Option(name: .shortAndLong, help: "Battery check interval in seconds")
    var batteryInterval: Int = 60

    func run() throws {
        logger.info("Starting watch mode (poll: \(interval)s, battery: \(batteryInterval)s)")
        let detector = ProcessDetector()
        var assertion = PowerAssertion(name: "lidwatch-watch")
        let battery = BatteryMonitor(checkInterval: TimeInterval(batteryInterval))
        var lastBatteryCheck = Date.distantPast
        var wasActive = false

        print("Watching for agent processes (poll every \(interval)s)...")
        print("Press Ctrl+C to stop.")
        print()

        signal(SIGINT) { _ in
            print("\nStopping watch mode...")
            Darwin.exit(0)
        }
        signal(SIGTERM) { _ in
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
                }
                wasActive = true

                if now.timeIntervalSince(lastBatteryCheck) >= battery.checkInterval {
                    let status = battery.checkBattery()
                    lastBatteryCheck = now
                    switch status {
                    case .critical(let level):
                        print("[\(timestamp())] CRITICAL: Battery at \(level)% — connect power immediately!")
                    case .warning(let level):
                        print("[\(timestamp())] WARNING: Battery at \(level)% — consider connecting power")
                    default:
                        break
                    }
                }
            } else if assertion.isActive {
                assertion.release()
                print("[\(timestamp())] No agents detected — sleep prevention OFF")
                logger.info("Assertion released — all agents exited")
                wasActive = false
            } else if wasActive {
                wasActive = false
            }

            Thread.sleep(forTimeInterval: TimeInterval(interval))
        }
    }
}

private func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}
