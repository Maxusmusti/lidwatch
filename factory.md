# Factory Configuration — lidwatch

## Project

- **Name:** lidwatch
- **Language:** Swift
- **Build system:** Swift Package Manager
- **Platform:** macOS 13+
- **Primary architecture:** arm64 (Apple Silicon)

## Modifiable Surfaces

- `Sources/lidwatch/**/*.swift`
- `Sources/LidwatchCore/**/*.swift`
- `Tests/**/*.swift`
- `Package.swift`
- `CLAUDE.md`
- `.github/workflows/*.yml`

## Fixed Surfaces

- `eval/score.py`

## Eval

- **Harness:** `python3 eval/score.py`
- **Threshold:** 0.5
- **Dimensions:** tests, type_check, lint, capability_surface, observability

## Eval Weights

- hygiene: 50
- growth: 50

## Target Branch

main
