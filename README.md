# lidwatch

Prevent your Mac from sleeping when you close the lid while AI agents are running. No external monitor needed.

Built for Apple Silicon. Works with Claude Code, Cursor, Aider, and any process you configure.

## The Problem

You close your MacBook lid while Claude Code runs a long task. macOS puts the machine to sleep. The SSH connection drops, the agent loses context, and hours of work are wasted.

Previous solutions required an external monitor for "clamshell mode." lidwatch eliminates that requirement entirely — it uses `pmset disablesleep` to prevent sleep even with the lid closed, with safety guards that auto-disable on low battery or after a max duration.

## Quick Start

### Menubar App (Recommended)

```bash
brew tap Maxusmusti/lidwatch
brew install lidwatch
```

1. Launch the Lidwatch menubar app
2. Click the menubar icon
3. Toggle **Lid-Close Prevention** ON
4. Enter your password when prompted (native macOS authorization dialog)
5. Close your lid and walk away
6. The app auto-disables when agents exit (or toggle OFF manually)

### CLI

```bash
# Watch for agents with lid-close prevention (uses sudo)
lidwatch watch --lid-close

# Or wrap a single command (idle sleep prevention only, no root needed)
lidwatch wrap -- claude
```

## How It Works

lidwatch uses `pmset disablesleep` to disable sleep system-wide, including lid-close sleep. This is the same mechanism macOS itself uses — it's not a hack or workaround.

- **Menubar app:** Prompts for your password via a native macOS authorization dialog (no terminal sudo)
- **CLI (`--lid-close`):** Uses `sudo pmset` — run from a terminal with sudo access
- **Fallback (`wrap`):** Uses `caffeinate -i -s` for idle sleep prevention only — no root required, but won't prevent lid-close sleep

### Safety Guards

lidwatch includes multiple safety guards to prevent your Mac from running unattended indefinitely:

| Guard | Behavior |
|---|---|
| Low battery | Auto-disables lid-close prevention below 20% battery |
| Max duration | Auto-disables after 4 hours (configurable via `--max-hours`) |
| Agent exit | Auto-disables when all watched agent processes exit |
| Stuck detection | On app launch, checks for leftover `disablesleep=1` from a prior crash |

**Thermal warning:** When lid-close prevention is active, keep your Mac on a hard, ventilated surface — never on fabric or bedding. Closed-lid operation with blocked ventilation can increase temperatures significantly.

## Installation

### Homebrew

```bash
brew tap Maxusmusti/lidwatch
brew install lidwatch
```

### Build from Source

Requires Swift 5.9+ and macOS 13+.

```bash
git clone https://github.com/meyceoz/way-safely-close-mac.git
cd way-safely-close-mac
swift build -c release
# Binary is at .build/release/lidwatch
cp .build/release/lidwatch /usr/local/bin/
```

### Menubar App

```bash
swift build -c release --product LidwatchApp
.build/release/LidwatchApp
```

## CLI Usage

### `lidwatch watch`

Daemon mode. Polls for agent processes and creates power assertions when any are detected. With `--lid-close`, also enables `pmset disablesleep` for full lid-close prevention.

```bash
# Watch with lid-close prevention (recommended)
lidwatch watch --lid-close

# Custom poll interval and max duration
lidwatch watch --lid-close --interval 10 --max-hours 8

# Idle sleep prevention only (no root required)
lidwatch watch
```

### `lidwatch wrap -- <command>`

Wraps a command with `caffeinate -i -s` to prevent idle and system sleep for the command's duration. No root required. Does not prevent lid-close sleep.

```bash
lidwatch wrap -- claude
lidwatch wrap -- python train.py
lidwatch wrap -- npm run build
```

### `lidwatch check`

Shows system status including `pmset disablesleep` state, clamshell readiness, battery level, and detected agents.

```bash
lidwatch check
```

### `lidwatch status`

Shows system information, active power assertions, and detected agent processes.

```bash
lidwatch status
```

## Configuration

### Custom Agent Watchlist

By default, lidwatch watches for: `claude`, `cursor`, `aider`, `codex`.

To add custom processes, create `~/.config/lidwatch/agents.json`:

```json
{
  "agents": ["claude", "cursor", "aider", "codex", "copilot", "myagent"]
}
```

## Comparison

| Feature | lidwatch | caffeinate | Amphetamine | claude-code-sleep-preventer |
|---|---|---|---|---|
| Lid-close prevention | Yes | No | No | No |
| No external display needed | Yes | N/A | N/A | N/A |
| Auto-detect AI agents | Yes | No | No | Claude only |
| Safety guards (battery/duration) | Yes | No | Partial | No |
| Native macOS auth | Yes | N/A | N/A | No |
| Battery monitoring | Yes | No | Yes | No |
| Configurable watchlist | Yes | N/A | N/A | No |
| Menubar app | Yes | No | Yes | No |
| CLI tool | Yes | Yes | No | Yes |
| Auto-release on exit | Yes | Yes (with -w) | Manual | Yes |
| Open source | Yes | Yes (built-in) | No | Yes |

## Architecture

```
Sources/
├── lidwatch/              CLI executable (Swift ArgumentParser)
│   ├── Lidwatch.swift       Entry point, command registration
│   ├── WrapCommand.swift    Wrap command with caffeinate
│   ├── WatchCommand.swift   Daemon mode with process polling + lid-close
│   ├── StatusCommand.swift  System info and assertions display
│   └── CheckCommand.swift   System checks including pmset state
├── LidwatchCore/          Shared library
│   ├── PowerAssertion.swift   IOKit power assertion management
│   ├── ProcessDetector.swift  Agent process scanning
│   ├── SafetyChecker.swift    Clamshell prerequisite validation
│   ├── SystemInfo.swift       Architecture, power, display detection
│   ├── BatteryMonitor.swift   Battery level monitoring and alerts
│   └── LidCloseManager.swift  pmset disablesleep management + safety guards
└── LidwatchApp/           SwiftUI menubar application
    ├── LidwatchApp.swift    App entry point with MenuBarExtra
    ├── AppState.swift       Observable state with lid-close integration
    ├── MenuBarView.swift    Dropdown menu UI with lid-close toggle
    ├── SettingsView.swift   Preferences panel
    └── NotificationManager.swift  User notifications
```

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (arm64) — primary target; Intel is best-effort
- Swift 5.9+ (build from source)
- Admin password (for lid-close prevention only)

## License

MIT
