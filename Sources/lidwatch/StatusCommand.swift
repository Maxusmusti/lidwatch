import ArgumentParser
import Foundation
import LidwatchCore
import os

private let logger = Logger(subsystem: "com.lidwatch.cli", category: "Status")

struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show current power assertions and agent processes"
    )

    func run() throws {
        let info = SystemInfo()

        print("System Information")
        print("  Architecture: \(info.chipArchitecture)")
        print("  AC Power: \(info.isOnACPower ? "Yes" : "No")")
        print("  External Displays: \(info.externalDisplayCount)")
        print()

        print("Power Assertions:")
        let pmsetOutput = try shellOutput("/usr/bin/pmset", "-g", "assertions")
        print(pmsetOutput)

        print("Agent Processes:")
        let agentNames = ["claude", "cursor", "aider", "codex"]
        let psOutput = try shellOutput("/bin/ps", "-eo", "pid,comm")
        let lines = psOutput.split(separator: "\n")
        var found = false
        for line in lines {
            let lower = line.lowercased()
            for agent in agentNames where lower.contains(agent) {
                print("  \(line.trimmingCharacters(in: .whitespaces))")
                found = true
                break
            }
        }
        if !found {
            print("  No known agent processes detected")
        }
    }
}

private func shellOutput(_ command: String, _ args: String...) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}
