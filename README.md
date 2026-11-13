# Vector Barrage

Native macOS missile-defense arcade game and fifth built-in Fun City cabinet.

## Current build

**v0.8.0 — continuous fire, live low-ammo and city warnings, varied missile speed**. Original SwiftUI + AppKit implementation for macOS 13+ with no third-party packages.

- Defend six cities using three selectable interceptor batteries.
- Enemy missiles, expanding interception zones, chain-reaction scoring and splitting missiles in later waves.
- Classic / Modern graphics and Cadet / Veteran / Ace difficulty.
- Progressive waves, ammo replenishment, score, city survival and wave-clear bonuses.
- Vector Drift-inspired right-side telemetry (score, wave, cities, inbound threats and battery ammunition).
- Restrained, non-animated layered terrain horizon in Modern mode; Classic keeps its clean background.
- Confirmed intercept shockwaves, short spark bursts and floating score callouts (Modern); a restrained ring in Classic.
- Timed chain-reaction combos, up to 4× point multipliers, wave-end combo bonus, and best-chain/intercepts telemetry.
- Distinct wide-front, flank, cluster and MIRV formation patterns; bounded simultaneous missiles and short recoveries between attack groups.
- Faster interceptor travel, instantaneous launch flashes and restrained combat feedback pulses.
- More visible atmospheric depth: gradient sky, three layered mountain ridges and faint distant structures in Modern mode.
- More distinctive operational cities (unique skylines, windows, antennas), detailed interceptor batteries and recognizable warhead silhouettes/trails.
- Classic display remains restrained; active gameplay and Control-key battery cycling are unchanged.
- Original synthesized launch, interception, chain, city-impact and wave-clear effects with a mute toggle.
- Custom Game lets you choose starting wave, missiles per wave, interceptor ammo, incoming speed, sounds and reduced flash. Applying rules starts a fresh game.
- Save Game and Resume retain up to five local battle snapshots via UserDefaults. Restored battles pause until P is pressed.
- Cities render 10% larger. Destroyed cities produce a mushroom cloud, expanding blast and full-playfield white flash; reduced-flash mode decreases brightness.
- Critical red flashing alert in right telemetry when any missile targeting a standing city has **25% or less** of its trajectory remaining; includes count and an intermittent warning sound.
- Larger battery selection labels and ammunition figures in telemetry.
- Each defensive blast awards an extra 300 points upon its third unique missile kill and 100 more for each additional missile; large on-screen combo bonus banner and unique sound. Counts belong to one interceptor explosion, not simultaneous independent explosions. Existing local saves remain readable.
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

## v0.7.0 additions

- **T** dispatches a visible supply truck that travels left → center → right in three seconds. On arrival, it evenly redistributes all ammunition still in the three batteries, preserving the total rounds. It does not manufacture ammunition.
- **N** fires the selected battery's one-use nuclear interceptor (3 total per battle). The center interceptor rises vertically to approximately mid-screen; flank interceptors angle 20 degrees inward. Each blast eliminates approximately one third of the missiles inbound at detonation and awards 45 points per intercepted missile. No launch if the inbound list is empty. Nuke status is displayed in the right telemetry.
- From wave 2, flying-wing stealth bomber encounters recur on an interval. Bomber can deploy missiles and can be destroyed by defensive blast zones; destruction gives +450 points, a large animated explosion, screen shake and sound. Original procedural aircraft drawing, no licensed artwork.
- New logistics/airborne indicators in right telemetry. Save-game snapshots include the new persistent gameplay state where available and older slots remain readable.
- Full flash and shake are reduced in the custom game's reduced-flash option.

**New controls**: T redistribute ammo; N launch selected battery's limited nuclear interceptor. Existing Control battery cycling, mouse fire, P pause, Return next wave remain.

## v0.8.0 improvements

- **Hold and drag the mouse** over the battlefield to launch a continuous stream of regular interceptors from the selected battery, approximately every 0.19 seconds. First shot fires immediately; releasing stops the stream. Every shot consumes one round.
- Battery ammunition counters and battery vector art shift to amber/orange when their supply reaches **20% or less** of configured per-battery ammunition capacity. Empty batteries turn red and produce a throttled dry-fire click when firing is attempted.
- Cities being targeted by an incoming missile in the final 25% of its flight path switch to orange/red and show an animated threat outline, synchronized with the proximity warning on telemetry. Alerts clear when the missile is destroyed.
- Each wave increases the potential speed and random speed spread of incoming missiles, capped to maintain playable response times.
- Previously created save slots remain readable; settings and truck redistribution continue to influence ammo warnings.
