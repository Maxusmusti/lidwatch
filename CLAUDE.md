# lidwatch

Lightweight macOS utility that prevents idle sleep while AI agents (Claude Code, Cursor, Aider) are active. Validates clamshell mode prerequisites on Apple Silicon.

## Build

```bash
swift build
swift test
swift run lidwatch status
swift run lidwatch wrap -- <command>
```

## Project Structure

- `Sources/lidwatch/` - CLI executable (Swift ArgumentParser)
- `Sources/LidwatchCore/` - Core library (PowerAssertion, SystemInfo)
- `Tests/LidwatchCoreTests/` - Unit tests
- `eval/` - Factory eval harness

## Conventions

- macOS 13+ deployment target
- Apple Silicon (arm64) primary architecture
- Swift 5.9+ with Swift Package Manager
- Use `os.Logger` for structured logging (subsystem: `com.lidwatch.*`)
- IOKit for power management APIs
- No `caffeinate -d` (display sleep prevention causes battery drain)
- Use `-i` (idle sleep) and `-s` (system sleep) only
