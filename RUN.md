# Running the Klack clone

Built app: `app/build/Klack.app` (paths below are relative to the repo root)

## Settings window (most reliable)

```bash
app/build/Klack.app/Contents/MacOS/Klack --settings
```

Opens the settings window directly. Click the sidebar to switch panes —
**Sound**, **Sleep** and **Stats** are built; General, Visualizer,
Notifications and About show a placeholder saying they were never published.
Scroll the Sound pane to reach the Tone Pad and Sound Effects.

## Menu bar app

```bash
open app/build/Klack.app
```

Runs as an accessory app: a "K" keycap appears in the menu bar, and clicking it
opens the popover. **Caveat on this Mac:** Alcove occupies the menu bar area, so
the status item may be hidden behind it. If you can't find the icon, use
`--settings` or `--demo` instead.

From the popover: hover the rows, drag the Sound slider, click the toggle,
"Klack Settings…" opens the settings window, "Quit Klack" quits.
Shortcuts: ⌥⌘K toggle · ⌘, settings · ⌘Q quit · Esc dismiss.

## Both panels, floating, for a fixed time

```bash
app/build/Klack.app/Contents/MacOS/Klack --demo 30
```

Shows the popover and the switches panel over the desktop for 30 seconds, then
quits. Hover a switch row to see the Preview label and play button light up.

## Sound

It makes sound now.

- **Immediately, no permission:** launch it and type into one of its own windows.
  A local key monitor drives the audio whenever a Klack window is focused.
- **System-wide:** needs Accessibility (System Settings ▸ Privacy & Security ▸
  Accessibility). The app checks `AXIsProcessTrusted()` and never prompts on its
  own; grant it there and relaunch. It prints `global=on` at launch when active.

Click a switch in the switches panel to load and preview that set. The popover's
toggle and volume slider drive the engine live.

Hear all seven without running anything:

```bash
open shots/klack-switches-demo.wav
```

27 seconds, one typing burst per switch in catalogue order.

**The sounds are not Klack's.** Klack's sets are the paid product. These are CC0
public-domain recordings of real mechanical keyboards from Freesound, sliced
into individual down/up strokes — full provenance and licence for every file in
`assets/switches/CREDITS.md`.

## Usage tracking and sleep triggers

Both are live.

```bash
Klack --usage       # what has been counted, and where it is stored
Klack --triggers    # read every sleep-trigger detector against your system
```

Keystrokes, clicks and dings are counted and attributed to the switch that was
loaded, then persisted to `~/Library/Application Support/KlackClone/usage.json`.
The Stats pane shows them live. `--usage --reset` clears the store.

Sleep triggers poll every 2 s; when one you have enabled reads active, the app
goes quiet without changing any of your settings. Click a trigger row in the
Sleep pane to enable or disable it. Seven of the ten detectors work; **Focus**,
**Now Playing** and **Calendar Event** report as unavailable rather than
guessing — see `LEDGER.md` for why.

## Settings

Persisted to `~/Library/Application Support/KlackClone/settings.json` and
restored at launch. The Sound and Sleep panes are interactive — toggles flip,
sliders and the Tone Pad knob drag, "Switch sound" cycles the catalogue.

```bash
Klack --settings-dump              # every value, and which are not wired
Klack --settings-dump --reset
Klack --set volume 0.35            # volume switch pitch panning spatial rapid modifiers tone
```

Every row reaches the engine. **Play sound through** routes to a real output
device (`Klack --devices` lists them and reads back where the engine actually
is); **Effects volume** scales the return-key ding and mouse click, separately
from the keystroke volume.

```bash
Klack --devices                       # outputs, and where the engine is routed
Klack --set output "MacBook Pro Speakers"
Klack --set effects 0.5
```

## What it still does not do

The General, Visualizer, Notifications and About panes have no published
reference and render a placeholder.

The build is unsigned and ad-hoc, so double-clicking in Finder may trip
Gatekeeper. Running the binary directly, as above, avoids that.

## Verification harness

```bash
tools/report.sh              # every number for the popover and switches panel
tools/check.sh               # rest + all interaction states
tools/live-stage.sh --live-backdrop   # measures the shipping window on screen
app/build/Klack.app/Contents/MacOS/Klack --motion | --keys | --glyphfloor | --vectorfloor
```
