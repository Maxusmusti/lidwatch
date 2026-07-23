import AppKit
import LidwatchCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusHeader
            Divider()

            if !appState.detectedAgents.isEmpty {
                agentSection
                Divider()
            }

            if let report = appState.clamshellReport {
                clamshellSection(report)
                Divider()
            }

            batterySection

            if appState.isAssertionActive && appState.showThermalWarnings {
                thermalAdvisory
                Divider()
            }

            forceToggle
            Divider()

            Button("Settings...") {
                openSettings()
            }
            Button("Quit Lidwatch") {
                appState.stopMonitoring()
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear {
            appState.refreshClamshell()
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isAssertionActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(appState.statusText)
                .font(.headline)
            Spacer()
        }
    }

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active Agents")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ForEach(appState.detectedAgents, id: \.pid) { agent in
                HStack {
                    Image(systemName: "terminal")
                        .frame(width: 16)
                    Text(agent.name)
                    Spacer()
                    Text("PID \(agent.pid)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    private func clamshellSection(_ report: ClamshellReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Clamshell Readiness")
                .font(.subheadline)
                .foregroundColor(.secondary)
            ForEach(report.checks.filter { $0.name != "Architecture" }, id: \.name) { check in
                HStack(spacing: 6) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(check.passed ? .green : .red)
                        .frame(width: 16)
                    Text(check.name)
                        .font(.callout)
                    Spacer()
                }
            }
            Text(report.readiness.description)
                .font(.caption)
                .foregroundColor(readinessColor(report.readiness))
        }
    }

    @ViewBuilder
    private var batterySection: some View {
        switch appState.batteryStatus {
        case .onAC:
            EmptyView()
        case .normal(let level):
            HStack(spacing: 6) {
                Image(systemName: batteryIcon(level))
                Text("Battery: \(level)%")
            }
            Divider()
        case .warning(let level):
            HStack(spacing: 6) {
                Image(systemName: "battery.25")
                    .foregroundColor(.orange)
                Text("Battery: \(level)% — connect power")
                    .foregroundColor(.orange)
            }
            Divider()
        case .critical(let level):
            HStack(spacing: 6) {
                Image(systemName: "battery.0")
                    .foregroundColor(.red)
                Text("Battery: \(level)% — CONNECT POWER")
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
            }
            Divider()
        }
    }

    private var thermalAdvisory: some View {
        HStack(spacing: 6) {
            Image(systemName: "thermometer.medium")
                .foregroundColor(.orange)
                .frame(width: 16)
            Text("Ensure Mac is on a hard, ventilated surface")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var forceToggle: some View {
        Toggle("Force Enable", isOn: Binding(
            get: { appState.isForceEnabled },
            set: { appState.setForceEnabled($0) }
        ))
    }

    private func batteryIcon(_ level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func readinessColor(_ readiness: ReadinessLevel) -> Color {
        switch readiness {
        case .ready: return .green
        case .partial: return .orange
        case .notReady: return .red
        }
    }

    private func openSettings() {
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
