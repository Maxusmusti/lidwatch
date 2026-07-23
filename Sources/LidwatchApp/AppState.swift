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

    @Published var isLidClosePreventionEnabled: Bool = false
    @Published var lidCloseError: String?
    @Published var lidCloseEnabledSince: Date?
    @Published var maxLidCloseDuration: TimeInterval = LidCloseManager.defaultMaxDuration

    private var assertion = PowerAssertion(name: "lidwatch-app")
    private var detector: ProcessDetector
    private let safetyChecker = SafetyChecker()
    private let batteryMonitor = BatteryMonitor()
    let notificationManager = NotificationManager()
    let lidCloseManager = LidCloseManager()

    private var pollTimer: Timer?
    private var batteryTimer: Timer?

    var statusText: String {
        if isLidClosePreventionEnabled {
            return "Lid-Close Protected"
        }
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

        checkStuckDisablesleep()
        startMonitoring()
    }

    func startMonitoring() {
        notificationManager.requestPermission()

        poll()
        checkBattery()
        refreshClamshell()
        syncLidCloseState()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBattery()
            self?.checkLidCloseSafetyGuards()
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
        if isLidClosePreventionEnabled {
            disableLidClosePrevention()
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

                if isLidClosePreventionEnabled {
                    disableLidClosePrevention()
                    notificationManager.send(
                        title: "Lid-Close Prevention Off",
                        body: "All agents exited — lid-close prevention disabled"
                    )
                }
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

    // MARK: - Lid-Close Prevention

    func toggleLidClosePrevention() {
        if isLidClosePreventionEnabled {
            disableLidClosePrevention()
        } else {
            enableLidClosePrevention()
        }
    }

    func enableLidClosePrevention() {
        lidCloseError = nil
        do {
            try lidCloseManager.enable()
            isLidClosePreventionEnabled = true
            lidCloseEnabledSince = Date()
            logger.info("Lid-close prevention enabled via GUI")
            notificationManager.send(
                title: "Lid-Close Prevention On",
                body: "Safe to close lid — sleep is disabled system-wide"
            )
        } catch LidCloseError.authenticationCancelled {
            lidCloseError = "Authentication cancelled"
            logger.info("User cancelled lid-close auth prompt")
        } catch {
            lidCloseError = error.localizedDescription
            logger.error("Failed to enable lid-close prevention: \(error.localizedDescription)")
        }
    }

    func disableLidClosePrevention() {
        lidCloseError = nil
        do {
            try lidCloseManager.disable()
            isLidClosePreventionEnabled = false
            lidCloseEnabledSince = nil
            logger.info("Lid-close prevention disabled via GUI")
        } catch {
            lidCloseError = error.localizedDescription
            logger.error("Failed to disable lid-close prevention: \(error.localizedDescription)")
        }
    }

    func syncLidCloseState() {
        isLidClosePreventionEnabled = lidCloseManager.isEnabled
        if isLidClosePreventionEnabled && lidCloseEnabledSince == nil {
            lidCloseEnabledSince = Date()
        }
    }

    private func checkLidCloseSafetyGuards() {
        guard isLidClosePreventionEnabled else { return }

        var batteryLevel = 100
        var isOnAC = true
        switch batteryStatus {
        case .normal(let level), .warning(let level), .critical(let level):
            batteryLevel = level
            isOnAC = false
        case .onAC:
            break
        }

        if lidCloseManager.shouldAutoDisable(batteryLevel: batteryLevel, isOnAC: isOnAC) {
            disableLidClosePrevention()
            notificationManager.send(
                title: "Lid-Close Prevention Auto-Disabled",
                body: "Battery below \(LidCloseManager.lowBatteryThreshold)% — sleep restored"
            )
            logger.warning("Auto-disabled lid-close prevention due to low battery")
            return
        }

        if let since = lidCloseEnabledSince,
           lidCloseManager.shouldAutoDisable(enabledSince: since, maxDuration: maxLidCloseDuration) {
            disableLidClosePrevention()
            let hours = Int(maxLidCloseDuration / 3600)
            notificationManager.send(
                title: "Lid-Close Prevention Auto-Disabled",
                body: "Maximum duration of \(hours) hours reached — sleep restored"
            )
            logger.warning("Auto-disabled lid-close prevention due to max duration")
        }
    }

    private func checkStuckDisablesleep() {
        if lidCloseManager.isEnabled {
            logger.warning("Detected stuck disablesleep=1 on app launch")
            isLidClosePreventionEnabled = true
            lidCloseEnabledSince = Date()
        }
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
