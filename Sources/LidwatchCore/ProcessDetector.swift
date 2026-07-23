import Foundation
import os

private let logger = Logger(subsystem: "com.lidwatch.core", category: "ProcessDetector")

public struct DetectedAgent: Sendable, CustomStringConvertible {
    public let name: String
    public let pid: Int32

    public init(name: String, pid: Int32) {
        self.name = name
        self.pid = pid
    }

    public var description: String {
        "\(name) (PID \(pid))"
    }
}

public protocol ProcessListing: Sendable {
    func runningProcesses() -> [(pid: Int32, name: String)]
}

public struct SystemProcessListing: ProcessListing {
    public init() {}

    public func runningProcesses() -> [(pid: Int32, name: String)] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-eo", "pid,comm"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            return output.split(separator: "\n").compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let spaceIdx = trimmed.firstIndex(of: " ") else { return nil }
                let pidStr = trimmed[trimmed.startIndex..<spaceIdx]
                    .trimmingCharacters(in: .whitespaces)
                guard let pid = Int32(pidStr) else { return nil }
                let comm = trimmed[spaceIdx...].trimmingCharacters(in: .whitespaces)
                let binaryName = (comm as NSString).lastPathComponent
                return (pid: pid, name: binaryName)
            }
        } catch {
            logger.error("Failed to list processes: \(error.localizedDescription)")
            return []
        }
    }
}

public struct AgentWatchlist: Codable, Sendable {
    public var agents: [String]

    public init(agents: [String] = Self.defaults) {
        self.agents = agents
    }

    public static let defaults = ["claude", "cursor", "aider", "codex"]

    public static func load() -> AgentWatchlist {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/lidwatch/agents.json")

        guard FileManager.default.fileExists(atPath: configPath.path) else {
            logger.debug("No custom watchlist at \(configPath.path), using defaults")
            return AgentWatchlist()
        }

        do {
            let data = try Data(contentsOf: configPath)
            let watchlist = try JSONDecoder().decode(AgentWatchlist.self, from: data)
            logger.info("Loaded \(watchlist.agents.count) agents from \(configPath.path)")
            return watchlist
        } catch {
            logger.warning("Failed to parse watchlist: \(error.localizedDescription), using defaults")
            return AgentWatchlist()
        }
    }
}

public struct ProcessDetector {
    public let watchlist: AgentWatchlist
    private let listing: ProcessListing

    public init(watchlist: AgentWatchlist = .load(), listing: ProcessListing = SystemProcessListing()) {
        self.watchlist = watchlist
        self.listing = listing
    }

    public func detect() -> [DetectedAgent] {
        let processes = listing.runningProcesses()
        var detected: [DetectedAgent] = []

        for (pid, name) in processes {
            let lowerName = name.lowercased()
            for agent in watchlist.agents {
                if lowerName == agent.lowercased() || lowerName.hasPrefix(agent.lowercased()) {
                    detected.append(DetectedAgent(name: name, pid: pid))
                    logger.info("Detected agent: \(name) (PID \(pid))")
                    break
                }
            }
        }

        if detected.isEmpty {
            logger.debug("No known agent processes detected")
        }
        return detected
    }

    public var hasActiveAgents: Bool {
        !detect().isEmpty
    }
}
