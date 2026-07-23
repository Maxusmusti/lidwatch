import LidwatchCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newProcessName: String = ""
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            processesTab
                .tabItem { Label("Processes", systemImage: "terminal") }
        }
        .frame(width: 420, height: 320)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section("Notifications") {
                Toggle("Show Thermal Warnings", isOn: Binding(
                    get: { appState.showThermalWarnings },
                    set: { appState.setShowThermalWarnings($0) }
                ))
            }
        }
        .padding()
    }

    private var processesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watched Process Names")
                .font(.headline)
            Text("Lidwatch activates sleep prevention when any of these processes are running.")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(appState.watchedProcessNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "terminal")
                            .foregroundColor(.secondary)
                        Text(name)
                        Spacer()
                        Button {
                            removeProcess(name)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 120)

            HStack {
                TextField("Process name", text: $newProcessName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addProcess() }
                Button("Add") {
                    addProcess()
                }
                .disabled(newProcessName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    appState.updateWatchlist(AgentWatchlist.defaults)
                }
            }
        }
        .padding()
    }

    private func addProcess() {
        let name = newProcessName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !appState.watchedProcessNames.contains(name) else { return }
        var names = appState.watchedProcessNames
        names.append(name)
        appState.updateWatchlist(names)
        newProcessName = ""
    }

    private func removeProcess(_ name: String) {
        var names = appState.watchedProcessNames
        names.removeAll { $0 == name }
        appState.updateWatchlist(names)
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLogin = !enabled
            launchAtLoginError = "Requires app bundle for launch-at-login"
        }
    }
}
