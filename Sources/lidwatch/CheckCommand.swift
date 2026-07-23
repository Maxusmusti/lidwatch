import ArgumentParser
import Foundation
import LidwatchCore
import os

private let logger = Logger(subsystem: "com.lidwatch.cli", category: "Check")

struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run pre-flight checks for clamshell mode readiness"
    )

    func run() throws {
        logger.info("Running pre-flight checks")
        let safety = SafetyChecker()
        let report = safety.checkClamshellReadiness()

        print("Clamshell Readiness Report")
        print("==========================")
        print()

        for check in report.checks {
            print(check)
        }
        print()

        switch report.readiness {
        case .ready:
            print("Status: READY — safe to close lid")
            if report.isAppleSilicon {
                print("  All Apple Silicon clamshell prerequisites met.")
            }
        case .partial:
            print("Status: PARTIAL — some prerequisites missing")
            let missing = report.checks.filter { !$0.passed }
            for item in missing {
                print("  → \(item.name): \(item.detail)")
            }
        case .notReady:
            print("Status: NOT READY — keep lid open")
            print("  Sleep prevention will protect against idle sleep only.")
        }

        print()

        let battery = BatteryMonitor()
        battery.printStatus()

        print()
        let detector = ProcessDetector()
        let agents = detector.detect()
        if agents.isEmpty {
            print("Agents: None detected")
        } else {
            print("Agents:")
            for agent in agents {
                print("  • \(agent)")
            }
        }
    }
}
