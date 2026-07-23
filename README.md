# lidwatch

Prevent macOS idle sleep while AI coding agents are running. Purpose-built for Apple Silicon Macs.

## The Problem

You close your MacBook lid while Claude Code, Cursor, or Aider runs a long task. macOS puts the machine to sleep. The SSH connection drops, the agent loses context, and hours of work are wasted.

`lidwatch` solves this by creating IOKit power assertions that prevent idle sleep while agent processes are active — and automatically releasing them when agents exit. On Apple Silicon, it also validates whether your setup supports clamshell mode (lid-closed operation) before you close the lid.

## Quick Start

```bash
# Install via Homebrew (once the tap is set up)
brew tap meyceoz/lidwatch
brew install lidwatch

# Wrap a command — prevents sleep for its duration
lidwatch wrap -- claude

# Or watch for agent processes in the background
lidwatch watch
```

## Installation

### Homebrew

```bash
brew tap meyceoz/lidwatch
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

The menubar app (`LidwatchApp`) provides a visual interface with the same functionality as the CLI.

```bash
swift build -c release --product LidwatchApp
# Run the app
.build/release/LidwatchApp
```

## Usage

### `lidwatch wrap -- <command>`

Wraps a command with `caffeinate -i -s` to prevent idle and system sleep for the command's duration. The sleep assertion is automatically released when the command exits.

```bash
# Prevent sleep while Claude Code runs
lidwatch wrap -- claude

# Prevent sleep for any long-running command
lidwatch wrap -- python train.py
lidwatch wrap -- npm run build
```

### `lidwatch watch`

Daemon mode. Polls for known agent processes and creates a power assertion when any are detected. Releases when all agents exit. Monitors battery level and warns at 20% (critical at 10%).

```bash
# Start watching with default 5-second poll interval
lidwatch watch

# Custom poll and battery check intervals
lidwatch watch --interval 10 --battery-interval 30
```

### `lidwatch status`

Shows system information, active power assertions, and detected agent processes.

```bash
lidwatch status
```

Output:

```
System Information
  Architecture: Apple Silicon
  AC Power: Yes
  External Displays: 1

Power Assertions:
  ...

Agent Processes:
  12345 claude
```

### `lidwatch check`

Runs pre-flight checks for clamshell mode (lid-closed operation). Reports whether your setup meets Apple Silicon's hardware requirements.

```bash
lidwatch check
```

Output:

```
Clamshell Readiness Report
==========================

  ✓ Architecture: Apple Silicon
  ✓ AC Power: Connected
  ✓ External Display: Connected
  ✓ External Keyboard: Connected
  ✓ External Mouse/Trackpad: Connected

Status: READY — safe to close lid
```

## Clamshell Mode (Lid-Closed Operation)

On Apple Silicon Macs, closing the lid triggers hardware-level sleep that **no software can override**. To use your Mac with the lid closed, you need **clamshell mode**, which requires:

| Prerequisite | Required | Why |
|---|---|---|
| External display | Yes | macOS needs a display to keep the system awake |
| AC power | Yes | Apple Silicon will not enter clamshell mode on battery |
| External keyboard | Recommended | You need input after closing the lid |
| External mouse/trackpad | Recommended | You need a pointing device after closing the lid |

When all prerequisites are met, macOS enters clamshell mode automatically when you close the lid — the system stays awake and uses the external display.

**What `lidwatch` does and doesn't do:**

- **Does:** Prevent *idle* sleep (the kind that happens after inactivity with the lid open)
- **Does:** Validate clamshell prerequisites so you know if lid-closed operation is safe
- **Does:** Monitor battery and warn before it gets critically low
- **Does not:** Override lid-close sleep — that's a hardware behavior on Apple Silicon that no software can bypass

Run `lidwatch check` before closing your lid to verify your setup is ready.

## Configuration

### Custom Agent Watchlist

By default, `lidwatch` watches for: `claude`, `cursor`, `aider`, `codex`.

To add custom processes, create `~/.config/lidwatch/agents.json`:

```json
{
  "agents": ["claude", "cursor", "aider", "codex", "copilot", "myagent"]
}
```

## Safety

### Thermal

When sleep prevention is active with the lid closed:

- Place your Mac on a hard, ventilated surface — never on fabric or bedding
- Closed-lid operation with blocked ventilation can increase temperatures by ~13°C
- The menubar app shows a thermal advisory when assertions are active

### Battery

- `lidwatch` uses `caffeinate -i -s` (idle + system sleep prevention only)
- It does **not** use `-d` (display sleep prevention), which causes 1.4x faster battery drain
- Battery warnings trigger at 20%, critical alerts at 10%
- Connect AC power before starting long agent sessions

## Comparison

| Feature | lidwatch | caffeinate | Amphetamine | claude-code-sleep-preventer |
|---|---|---|---|---|
| Auto-detect AI agents | Yes | No | No | Claude only |
| Clamshell validation | Yes | No | No | No |
| Battery monitoring | Yes | No | Yes | No |
| Configurable watchlist | Yes | N/A | N/A | No |
| Menubar app | Yes | No | Yes | No |
| CLI tool | Yes | Yes | No | Yes |
| Auto-release on exit | Yes | Yes (with -w) | Manual | Yes |
| Apple Silicon aware | Yes | No | Partial | No |
| Open source | Yes | Yes (built-in) | No | Yes |

## Architecture

```
Sources/
├── lidwatch/              CLI executable (Swift ArgumentParser)
│   ├── Lidwatch.swift       Entry point, command registration
│   ├── WrapCommand.swift    Wrap command with caffeinate
│   ├── WatchCommand.swift   Daemon mode with process polling
│   ├── StatusCommand.swift  System info and assertions display
│   └── CheckCommand.swift   Clamshell readiness checks
├── LidwatchCore/          Shared library
│   ├── PowerAssertion.swift   IOKit power assertion management
│   ├── ProcessDetector.swift  Agent process scanning
│   ├── SafetyChecker.swift    Clamshell prerequisite validation
│   ├── SystemInfo.swift       Architecture, power, display detection
│   └── BatteryMonitor.swift   Battery level monitoring and alerts
└── LidwatchApp/           SwiftUI menubar application
    ├── LidwatchApp.swift    App entry point with MenuBarExtra
    ├── AppState.swift       Observable state bridging core library
    ├── MenuBarView.swift    Dropdown menu UI
    ├── SettingsView.swift   Preferences panel
    └── NotificationManager.swift  User notifications
```

## Requirements

- macOS 13+ (Ventura or later)
- Apple Silicon (arm64) — primary target; Intel is best-effort
- Swift 5.9+ (build from source)

## License

MIT
