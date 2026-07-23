# lidwatch

Lightweight macOS utility that prevents sleep (including lid-close sleep) while AI agents (Claude Code, Cursor, Aider) are active. Uses `pmset disablesleep` for lid-close prevention with safety guards.

## Build

```bash
swift build
swift test
swift run lidwatch status
swift run lidwatch wrap -- <command>
swift run lidwatch check
swift run lidwatch watch
```

### Menubar App

```bash
swift build --product LidwatchApp
swift run LidwatchApp
```

## CLI Commands

- `lidwatch wrap -- <command>` — Wrap a command with caffeinate to prevent idle sleep
- `lidwatch status` — Show system info, power assertions, and detected agents
- `lidwatch check` — Show system status including pmset disablesleep state
- `lidwatch watch` — Daemon mode: poll for agents, assert sleep prevention while active
- `lidwatch watch --lid-close` — Daemon mode with lid-close prevention via pmset disablesleep (requires sudo)

## Project Structure

- `Sources/lidwatch/` - CLI executable (Swift ArgumentParser)
- `Sources/LidwatchCore/` - Core library (PowerAssertion, ProcessDetector, SafetyChecker, BatteryMonitor, SystemInfo, LidCloseManager)
- `Sources/LidwatchApp/` - SwiftUI menubar app (MenuBarExtra, AppState, SettingsView, NotificationManager)
- `Tests/LidwatchCoreTests/` - Unit tests
- `scripts/` - Homebrew formula template
- `.github/workflows/` - CI and release automation
- `eval/` - Factory eval harness

## Conventions

- macOS 13+ deployment target
- Apple Silicon (arm64) primary architecture
- Swift 5.9+ with Swift Package Manager
- Use `os.Logger` for structured logging (subsystem: `com.lidwatch.*`)
- IOKit for power management APIs
- No `caffeinate -d` (display sleep prevention causes battery drain)
- Use `-i` (idle sleep) and `-s` (system sleep) only
