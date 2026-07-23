import Combine
import Foundation
import LidwatchCore
import os

private let logger = Logger(subsystem: "com.lidwatch.app", category: "AppState")

final class AppState: ObservableObject {
    @Published var detectedAgents: [DetectedAgent] = []
    @Published var isAssertionActive: Bool = false
    @Published var clamshellReport: ClamshellReport?
    @Published var batteryStatus: BatteryStatus = .onAC
    @Published var isForceEnabled: Bool = false
    @Published var watchedProcessNames: [String]
    @Published var showThermalWarnings: Bool = true

    private var assertion = PowerAssertion(name: "lidwatch-app")
    private var detector: ProcessDetector
    private let safetyChecker = SafetyChecker()
    private let batteryMonitor = BatteryMonitor()
    let notificationManager = NotificationManager()

    private var pollTimer: Timer?
    private var batteryTimer: Timer?

    var statusText: String {
        if isAssertionActive {
            return detectedAgents.isEmpty ? "Active (Forced)" : "Active"
        }
        return "Idle"
    }

    var batteryLevel: Int? {
        switch batteryStatus {
        case .normal(let level), .warning(let level), .critical(let level):
            return level
        case .onAC:
            return nil
        }
    }

    init() {
        UserDefaults.standard.register(defaults: ["showThermalWarnings": true])

        let saved = UserDefaults.standard.stringArray(forKey: "watchedProcessNames")
        let names = saved ?? AgentWatchlist.defaults
        self.watchedProcessNames = names
        self.showThermalWarnings = UserDefaults.standard.bool(forKey: "showThermalWarnings")
        self.detector = ProcessDetector(watchlist: AgentWatchlist(agents: names))
        startMonitoring()
    }

    func startMonitoring() {
        notificationManager.requestPermission()

        poll()
        checkBattery()
        refreshClamshell()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        logger.info("Monitoring started")
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        batteryTimer?.invalidate()
        batteryTimer = nil
        if assertion.isActive {
            assertion.release()
            isAssertionActive = false
        }
        logger.info("Monitoring stopped")
    }

    func poll() {
        let agents = detector.detect()
        let hadAgents = !detectedAgents.isEmpty
        detectedAgents = agents

        let shouldBeActive = isForceEnabled || !agents.isEmpty

        if shouldBeActive && !assertion.isActive {
            assertion.create()
            isAssertionActive = true
            if !agents.isEmpty && !hadAgents {
                let names = agents.map(\.name).joined(separator: ", ")
                notificationManager.send(
                    title: "Agent Detected",
                    body: "Sleep prevention activated for: \(names)"
                )
                logger.info("Assertion activated for agents: \(names)")
            }
        } else if !shouldBeActive && assertion.isActive {
            assertion.release()
            isAssertionActive = false
            if hadAgents {
                notificationManager.send(
                    title: "Agents Exited",
                    body: "Sleep prevention deactivated"
                )
                logger.info("Assertion released — all agents exited")
            }
        }
    }

    func checkBattery() {
        let previousStatus = batteryStatus
        batteryStatus = batteryMonitor.checkBattery()

        if case .warning(let level) = batteryStatus, !isWarningOrCritical(previousStatus) {
            notificationManager.send(
                title: "Battery Low",
                body: "Battery at \(level)% — consider connecting power"
            )
        } else if case .critical(let level) = batteryStatus, !isCritical(previousStatus) {
            notificationManager.send(
                title: "Battery Critical",
                body: "Battery at \(level)% — connect power immediately"
            )
        }
    }

    func refreshClamshell() {
        clamshellReport = safetyChecker.checkClamshellReadiness()
    }

    func setForceEnabled(_ enabled: Bool) {
        isForceEnabled = enabled
        poll()
        if enabled {
            refreshClamshell()
        }
    }

    func updateWatchlist(_ names: [String]) {
        watchedProcessNames = names
        UserDefaults.standard.set(names, forKey: "watchedProcessNames")
        detector = ProcessDetector(watchlist: AgentWatchlist(agents: names))
        poll()
    }

    func setShowThermalWarnings(_ show: Bool) {
        showThermalWarnings = show
        UserDefaults.standard.set(show, forKey: "showThermalWarnings")
    }

    private func isWarningOrCritical(_ status: BatteryStatus) -> Bool {
        switch status {
        case .warning, .critical: return true
        default: return false
        }
    }

    private func isCritical(_ status: BatteryStatus) -> Bool {
        if case .critical = status { return true }
        return false
    }

    deinit {
        stopMonitoring()
    }
}
