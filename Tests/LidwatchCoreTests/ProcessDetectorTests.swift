import Testing

@testable import LidwatchCore

struct MockProcessListing: ProcessListing {
    let processes: [(pid: Int32, name: String)]

    func runningProcesses() -> [(pid: Int32, name: String)] {
        processes
    }
}

@Suite("ProcessDetector")
struct ProcessDetectorTests {
    @Test func detectsKnownAgents() {
        let mock = MockProcessListing(processes: [
            (pid: 100, name: "loginwindow"),
            (pid: 200, name: "claude"),
            (pid: 300, name: "Finder"),
            (pid: 400, name: "cursor"),
        ])
        let detector = ProcessDetector(watchlist: AgentWatchlist(), listing: mock)
        let detected = detector.detect()

        #expect(detected.count == 2)
        #expect(detected.contains { $0.name == "claude" && $0.pid == 200 })
        #expect(detected.contains { $0.name == "cursor" && $0.pid == 400 })
    }

    @Test func detectsNoAgentsWhenNoneRunning() {
        let mock = MockProcessListing(processes: [
            (pid: 1, name: "launchd"),
            (pid: 100, name: "Finder"),
            (pid: 200, name: "Safari"),
        ])
        let detector = ProcessDetector(watchlist: AgentWatchlist(), listing: mock)
        let detected = detector.detect()
        #expect(detected.isEmpty)
    }

    @Test func hasActiveAgentsProperty() {
        let mockWithAgent = MockProcessListing(processes: [
            (pid: 123, name: "aider"),
        ])
        let detectorActive = ProcessDetector(watchlist: AgentWatchlist(), listing: mockWithAgent)
        #expect(detectorActive.hasActiveAgents)

        let mockWithout = MockProcessListing(processes: [
            (pid: 1, name: "launchd"),
        ])
        let detectorInactive = ProcessDetector(watchlist: AgentWatchlist(), listing: mockWithout)
        #expect(!detectorInactive.hasActiveAgents)
    }

    @Test func customWatchlist() {
        let watchlist = AgentWatchlist(agents: ["myagent", "otheragent"])
        let mock = MockProcessListing(processes: [
            (pid: 10, name: "claude"),
            (pid: 20, name: "myagent"),
        ])
        let detector = ProcessDetector(watchlist: watchlist, listing: mock)
        let detected = detector.detect()

        #expect(detected.count == 1)
        #expect(detected[0].name == "myagent")
    }

    @Test func defaultWatchlistContainsExpectedAgents() {
        let defaults = AgentWatchlist.defaults
        #expect(defaults.contains("claude"))
        #expect(defaults.contains("cursor"))
        #expect(defaults.contains("aider"))
        #expect(defaults.contains("codex"))
    }

    @Test func detectedAgentDescription() {
        let agent = DetectedAgent(name: "claude", pid: 42)
        #expect(agent.description == "claude (PID 42)")
    }

    @Test func prefixMatching() {
        let mock = MockProcessListing(processes: [
            (pid: 500, name: "claude-code"),
        ])
        let detector = ProcessDetector(watchlist: AgentWatchlist(), listing: mock)
        let detected = detector.detect()
        #expect(detected.count == 1)
        #expect(detected[0].name == "claude-code")
    }

    @Test func caseInsensitiveMatching() {
        let mock = MockProcessListing(processes: [
            (pid: 600, name: "Cursor"),
        ])
        let detector = ProcessDetector(watchlist: AgentWatchlist(), listing: mock)
        let detected = detector.detect()
        #expect(detected.count == 1)
    }
}
