import ArgumentParser
import Foundation
import os

private let logger = Logger(subsystem: "com.lidwatch.cli", category: "Wrap")

struct Wrap: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Wrap a command with caffeinate to prevent idle sleep"
    )

    @Argument(parsing: .captureForPassthrough, help: "The command to wrap")
    var command: [String]

    func run() throws {
        guard !command.isEmpty else {
            throw ValidationError("No command specified")
        }

        let cmdDescription = command.joined(separator: " ")
        logger.info("Wrapping command with caffeinate -i -s: \(cmdDescription)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-i", "-s"] + command
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        try process.run()
        process.waitUntilExit()

        signal(SIGINT, SIG_DFL)
        signal(SIGTERM, SIG_DFL)

        let status = process.terminationStatus
        logger.info("Wrapped command exited with status \(status)")
        if status != 0 {
            throw ExitCode(status)
        }
    }
}
