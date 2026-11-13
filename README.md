# Vector Barrage

Native macOS missile-defense arcade game and fifth built-in Fun City cabinet.

## Current build

**v0.2.0 — telemetry and atmospheric horizon**. Original SwiftUI + AppKit implementation for macOS 13+ with no third-party packages.

- Defend six cities using three selectable interceptor batteries.
- Enemy missiles, expanding interception zones, chain-reaction scoring and splitting missiles in later waves.
- Classic / Modern graphics and Cadet / Veteran / Ace difficulty.
- Progressive waves, ammo replenishment, score, city survival and wave-clear bonuses.
- Vector Drift-inspired right-side telemetry (score, wave, cities, inbound threats and battery ammunition).
- Restrained, non-animated layered terrain horizon in Modern mode; Classic keeps its clean background.
- Bundle identifier: `io.vectorbarrage.game`.

## Run on your Mac

```bash
mkdir -p ~/Documents/GitHub
cd ~/Documents/GitHub
git clone https://github.com/peter-dietrich/vector-barrage.git
cd vector-barrage
git switch main
git pull --ff-only origin main
open VectorBarrage.xcodeproj
```

In Xcode select **VectorBarrage**, **My Mac**, and press **Command-R**.

Or compile from Terminal:

```bash
xcodebuild -project VectorBarrage.xcodeproj -scheme VectorBarrage -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

## Controls

| Control | Action |
| --- | --- |
| Return | Start / advance to the next wave / restart after game over |
| Mouse click | Fire an interceptor at the clicked location |
| Control (tap) | Cycle left → center → right → left battery |
| Space | Fire at the last cursor location |
| P | Pause / resume |
| R | Start a new game |

If keyboard input does not register, click inside the game window to focus it.

## Fun City integration

Fun City includes a built-in **Vector Barrage** cabinet after the launcher update merged as PR #8. The launcher can open the game once macOS recognizes the `io.vectorbarrage.game` bundle. For local Xcode builds, select **LOCATE GAME** and point it to the built `VectorBarrage.app` (commonly in Xcode DerivedData `Build/Products/Debug`).

A downloadable signed game is not published yet. Fun City's **DOWNLOAD GAME** action requires a future GitHub Release asset named `VectorBarrage-macOS.zip` with its integrity digest. The current prototype has not been compiled or tested on a Mac by this assistant.

## Intellectual property

An original game inspired by the classic missile-defense arcade genre. No Atari/Missile Command imagery or audio was copied.
