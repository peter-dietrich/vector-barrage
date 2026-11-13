# Vector Barrage

Native macOS missile-defense arcade game and fifth built-in Fun City cabinet.

## Current build

**v1.2.5 — claim legacy high-score initials**. Original SwiftUI + AppKit implementation for macOS 13+ with no third-party packages.

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
- Classic display remains restrained; active gameplay and Tab-key battery cycling are unchanged.
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
| Tab (tap) | Cycle left → center → right → left battery |
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

**New controls**: T redistribute ammo; N launch selected battery's limited nuclear interceptor. Existing Tab battery cycling, mouse fire, P pause, Return next wave remain.

## v0.8.0 improvements

- **Hold and drag the mouse** over the battlefield to launch a continuous stream of regular interceptors from the selected battery, approximately every 0.19 seconds. First shot fires immediately; releasing stops the stream. Every shot consumes one round.
- Battery ammunition counters and battery vector art shift to amber/orange when their supply reaches **20% or less** of configured per-battery ammunition capacity. Empty batteries turn red and produce a throttled dry-fire click when firing is attempted.
- Cities being targeted by an incoming missile in the final 25% of its flight path switch to orange/red and show an animated threat outline, synchronized with the proximity warning on telemetry. Alerts clear when the missile is destroyed.
- Each wave increases the potential speed and random speed spread of incoming missiles, capped to maintain playable response times.
- Previously created save slots remain readable; settings and truck redistribution continue to influence ammo warnings.

## v0.9.0 bomber improvements

- Stealth bombers are now recognizable **side-profile** flying-wing aircraft (mirrored to match their direction of travel) with a nose, cockpit, wing, engine outlets and bomb bay.
- Bombs use an independent gravity-driven **forward-and-downward arc**. They inherit horizontal aircraft velocity and accelerate toward the ground; they are no longer rendered or moved as diagonal homing missiles.
- Bomb releases are timed **before the aircraft reaches the target**, using a predicted ballistic landing point and the city locations. Each city is targeted at most once per bomber pass, and shots are spaced to avoid rapid-fire bomb spam.
- Falling bombs can be shot down by expanding player interceptor blast zones and earn 50 points; unopposed hits trigger normal city-destruction effects.
- Falling bomb positions/velocities are included in local saved battles; older save slots remain readable.

## v1.0.0 scenery and controls

- **Tab** now cycles left → center → right missile batteries, replacing Control. The top-level on-screen instruction has been updated. The game view must have focus to receive key events.
- New battles choose a random hour. Each new wave advances the clock **2 hours 45 minutes**, moving through dawn, day, dusk, night, and back again. Telemetry shows the time and daylight period.
- Modern mode now features a wave-sensitive gradient sky with a dim sun/moon, a seeded procedural starfield in the spirit of Vector Drift, slowly drifting clouds, and three significantly more varied layered mountain ridges with atmospheric depth.
- Stars fade in sunlight, distant mountains brighten and desaturate by day, and ambient scenery colors shift with daylight. Gameplay effects and threat contrast remain prioritized. Classic mode remains simple.
- Saves retain the current scenery seed and time; earlier saves use a safe default.

## v1.1.0 meteor encounters

- From **wave 3**, slowly descending armored meteors enter the sky. Each meteor requires **three separate interceptor explosion hits** to destroy. Three small armor indicators and increasingly visible cracks show damage.
- Upon the third hit the meteor breaks apart in a dramatic white flash, shockwave, debris shower and screen shake. The existing reduced-flash setting reduces the flash. A distinct crack and shatter sound accompanies impact.
- Each breakup releases **four independently interceptable, dangerous fragments** with diverging paths. Fragments cannot be erased by the same pre-existing explosion that shattered the parent meteor; subsequent blasts can destroy them.
- Waves **3–5 feature one meteor per wave**. Wave 6 onward retains at least one meteor, with increasing random chances of a second (and an occasional third on much later waves).
- Meteors and unneutralized fragments can destroy surviving cities. Wave completion waits for all scheduled meteors and their fragments to resolve.
- Meteor health, hit-blast IDs, active meteor positions, and wave scheduling are included in saved battles. Earlier saves remain readable.

## v1.1.1 ammunition progression

- Default loadout increased from **12 to 15** interceptors per battery in wave 1.
- Each new wave adds **2 more rounds per battery** to the replenished loadout: wave 1 = 15, wave 2 = 17, wave 3 = 19, etc. The formula also applies to Custom Games starting in higher waves, using the custom starting ammunition as the wave-1 base.
- Low ammunition warnings continue to trigger at 20% of each wave's loadout. Saved battles retain their actual remaining rounds.

## v1.2.0 Custom Game controls

The **Custom Game** window is now scrollable and organized by system, with **Restore Defaults**, **Cancel** and **Apply & Start** buttons. Customizing starts a new game. The following gameplay values are editable and saved with each battle:

- **Start conditions:** difficulty, Classic/Modern display, starting wave.
- **Defenses:** wave-1 ammunition per battery, additional rounds per wave, sustained-fire shots/sec, interceptor velocity, blast radius, three nuclear interceptors on/off, ammo-truck transfer time, third-hit bonus score.
- **Missile waves:** wave density, enemy speed, enemy spawn frequency, MIRV splitting missiles on/off.
- **Meteors:** on/off, first wave, distinct interceptor hits needed, breakup fragment quantity, movement speed and encounter frequency.
- **Bombers:** on/off, first appearance wave, flight speed and appearance frequency.
- **Alerts:** low ammo percent and incoming missile final-path proximity percent.
- **Scenery:** dynamic landscape on/off, starfield and drifting clouds on/off, random/fixed start hour and hours advanced between waves.
- **Effects:** sounds on/off and reduced flash/shake.

The default values preserve the established game balance (15 missiles per battery and +2 each wave, first meteor wave 3, first bomber wave 2, 20% ammo warning, 25% proximity warning). Fixed battlefield structure (three batteries, six cities) is not changeable because the positions and UI are designed around those counts. Existing saves remain readable using defaults for newly introduced controls.

## v1.2.1 — perimeter controls and saved Custom Game setups

- The game's perimeter now aligns with **Vector Drift**: a two-row header with title, version and main actions above graphical difficulty/graphics selectors, a compact lower tactical strip, and streamlined keyboard help at the bottom.
- The new **Custom Game** preset library saves independently of an in-progress battle. Enter a name and click **Save Setup**; the setup includes the complete game rules, difficulty, and visual mode. Saving under an existing name updates that preset.
- Use **Load Saved Setup** to populate the editor and **Apply & Start** to play with those settings. Use **Delete Setup** to remove a named preset. Presets survive app restarts through local UserDefaults storage.
- Saved setups do not replace or overwrite Saved Games, which continue to preserve battle progress separately.
- The original keyboard controls and battery ammunition readouts remain available in the lower tactical strip.

## v1.2.2 — ammunition carryover

- Standard game begins with **12 rounds per battery**, not 15.
- Each new wave adds **one round per battery** to the unused rounds already in that battery. No old ammunition disappears. For example, finishing wave 1 with 5 / 8 / 3 leaves 6 / 9 / 4 at the start of wave 2.
- Higher-wave Custom Game starts use wave-1 ammunition plus the configured per-wave grant for previously skipped waves; subsequent waves preserve remaining rounds. Saved named custom setups retain their own base ammo and per-wave grant settings.
- Low-ammo alerts compare the live remaining rounds against 20% (or configured value) of that battery's actual starting rounds for the wave, including carried ammunition.
- Saved battles retain ammunition and their per-battery wave-opening capacity. Older saves remain loadable.

## v1.2.3 — high score

The highest score achieved on this Mac is stored in local UserDefaults and displayed both in the score strip and the right telemetry panel. The record updates as soon as the current score exceeds it, including during a wave, and persists across new games and app restarts. Existing saved battles and named custom game setups remain independent of the record.

## v1.2.4 — name the high-score holder

After a new all-time high-score run ends, the player enters up to three uppercase initials. The initials persist locally beside the high-score value in both right-hand telemetry and the lower score strip. Existing numeric high scores remain valid and show `---` until a new record holder submits initials.

## v1.2.5 — claim existing records

If a high-score value was saved before initials were introduced, the game now prompts for initials on launch and includes a **Claim High Score** button in the top toolbar until claimed. The initials are saved to the existing record without requiring the player to beat it again. Future records still prompt when the run ends. The stored score is not reset.
