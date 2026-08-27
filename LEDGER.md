# Klack.app — clone ledger

Target: the **Klack macOS app UI** (v2.x). Klack is paid ($4.99, App Store id
6446206067), so the reference was assembled from research rather than from the
running app.

## Reference provenance

| source | what it gives | grade |
|---|---|---|
| tryklack.com hero — the vendor's DOM recreation of the app UI | exact geometry, colour, type, transitions and hover rules, read out of computed style | **primary**, captured at 1× and 2×, lossless PNG |
| App Store `screen_1.png` @2880×1800 | the same two panels, published by the vendor | corroboration — same design, labelled "Version 2.1" |
| 9to5Mac 2023, `…-3-copy.jpg` | the **v1.2.1** popover — a real capture of the running app | superseded design; used only for behaviour/shortcuts |
| App Store description, tryklack.com/faqs | feature list, menu-bar behaviour, permissions | behaviour rows |

The vendor ships this same mockup as its App Store screenshot, so it is the
canonical published depiction of the v2 UI. It is **not** a raw capture of the
running app. That is the reference's limit and the reason for the `UNSOURCED`
rows at the end.

Scale: reference captured at deviceScaleFactor **2** (primary) and **1**.
All table values are logical px at 1×.

## Verification method

The panels are translucent, so they have no appearance independent of what is
behind them. `--verify` therefore rebuilds the reference's exact page
composition — page background, wallpaper at its exact rect and radius, both
panels at their exact offsets — renders it through a real `NSWindow` +
`NSView.draw`, and crops the identical rectangles the reference was cropped
from. The shipping panels call the same renderers.

```
tools/report.sh     # every number below
tools/check.sh      # rest + all states
app/build.sh        # build Klack.app
Klack --verify --states --scale1 --backdrop
Klack --glyphfloor | --vectorfloor | --motion | --demo
```

## Measured floors

| floor | value | how |
|---|---|---|
| reference reproducibility | **0.00 %** both surfaces | Chrome captured twice |
| clone reproducibility | **0.00 %** both surfaces | window rendered twice |
| glyph rasteriser (Skia vs CoreText) | **36.76 %** of ink pixels | same font, size, weight, colour, line box, position; `tools/glyphfloor.mjs` |
| vector rasteriser (Skia vs CoreGraphics) | **3.14 %** of shape pixels, 0.07 % overall — **MATCH** | same shapes and geometry; `tools/vectorfloor.mjs` |
| wallpaper decode/resample | mean ∆ 1.50 vs 1.49 for the best of six filters | irreducible; a property of the reference asset |

Surface floor = ink coverage × 36.76 %.

| surface | ink | predicted floor | measured | × floor | non-text share |
|---|---|---|---|---|---|
| popover @2× | 2.16 % | 0.80 % | **1.07 %** | 1.34 | 8.4 % |
| switches @2× | 3.21 % | 1.18 % | **1.97 %** | 1.67 | 14.9 % |
| popover @1× | 2.36 % | 0.87 % | **1.55 %** | 1.78 | 28.2 % |
| switches @1× | 3.38 % | 1.24 % | **2.94 %** | 2.37 | 42.1 % |

Text rendering: `setShouldSmoothFonts` is **scale-dependent**, measured both
ways. At 2× ON halves the glyph residual (36.0 %/37.5 % of ink vs 47.4 %/52.0 %,
dark-on-light and light-on-dark); at 1× ON costs 1.55 %→1.97 % and
2.94 %→3.96 %. Subpixel positioning and quantisation changed nothing.

---

## A — Popover  (ref rect 288 × 370.5 at page 1044,668)

| element | property | reference | clone | Δ | status |
|---|---|---|---|---|---|
| panel | width × height | 288 × 370.5 | 288 × 370.5 | 0 | met |
| panel | corner radius | 24, circular | 24, circular (`CGPath(roundedRect:cornerWidth:)`) | 0 | met |
| panel | fill | `#fff7ed` @ 0.80 | same | 0 | met — empty interior regions max ∆ 1 |
| panel | top hairline | 1px `#fff7ed` @ 0.30 | same, outer-minus-padding-box fill | 0 | met |
| panel | backdrop | `blur(24px)` | Gaussian σ 23.10, edge-duplicated at the border box | 0 | met — σ and edge rule both measured from Chrome |
| panel | shadow | `0 25px 50px −12px rgba(41,37,36,.30)` | same, Gaussian σ = blur × 0.5305 | 0 | met — σ fitted against Chrome |
| panel | padding | 12 (+1 border-top → content at 13) | same | 0 | met |
| list | row gap | 2 | 2 | 0 | met |
| row Klack | box | 264 × 30.5, pad 4/12, radius 12,12,8,8 | same | 0 | met |
| row Klack | label | 15px/22.5 w700 `#292524` | same | 0 | met — advance width 40.57 vs 40.60 |
| toggle | track | 44 × 20 pill, `#00bba7` | same | 0 | met — teal extent 16..95 in both |
| toggle | knob | 26 × 16 pill, `#fff7ed`, shadow `0 1px 0 rgba/.1` | same | 0 | met — cream extent 50..115 vs 51..115 |
| toggle | knob travel | +14 on / 0 off | same | 0 | met |
| hdr rows | box | pad-top 11, margin-top 6, height 31 | same | 0 | met |
| hdr rows | label | 14px/20 w600 `#79716b` @ 0.75 | same | 0 | met |
| hdr rows | rule | 1px inset 12 l/r, `#292524` @ 0.10 | same, device-pixel snapped | 0 | met |
| slider | track | 240 × 4 pill, `#292524` @ 0.10 | same | 0 | met |
| slider | fill | 168 × 4 (70 %), `#292524` | same | 0 | met |
| slider | thumb | 20 × 16 pill, `#fff7ed`, shadow-sm | same | 0 | met — region ∆ 0.42 mean, 0.7 % |
| slider | thumb x | centre = `v × (240 − 20) + 10`; renders as `calc(70 % − 4px)` at 0.70 and `calc(40 % + 2px)` at 0.40 | same | 0 | met — **was a bug**: a fixed −4px offset is right only at 0.70, the one value the static reference shows. Caught by driving the live slider to 40 %; clone left edge 112.0 = reference 112.0 |
| sw preview | row box | 264 × 96 | same | 0 | met |
| sw preview | rows | 3 × 18, gap 12, top 4, bottom 6 | same | 0 | met |
| sw preview | chip / bar | 18², r6, `/0.15`; h6 r3 `/0.10`, w 96/80/112, gap 10 | same | 0 | met |
| sw preview | check | 14px box, pb-2 → 12px glyph, `/0.15` | same | 0 | met |
| sw preview | mask | `linear-gradient(to bottom, black, transparent)` | same | 0 | met — inverted at first, fixed |
| hdr Version | text | "Version" + 4 + "2.2" | same | 0 | met — 50.55 vs 50.70, 21.43 vs 21.50 |
| row Settings | box/label | 264 × 30.5, 15px/22.5 w500 | same | 0 | met |
| row Quit | box | margin-top 13, radius 8,8,12,12, rule at −7 | same | 0 | met |

### A — states

| element | state | reference | clone | Δ | status |
|---|---|---|---|---|---|
| row Settings | `:hover` | bg `#292524` @ 0.10, text → `#fff7ed` | same | ref changes 7.47 % of px, clone 7.47 %; change-maps agree to **0.31 %** | met — triggered and diffed |
| row Quit | `:hover` | as above | same | ref 7.44 %, clone 7.45 %; agree to **0.18 %** | met — triggered and diffed |
| rows | transition | `100 ms cubic-bezier(0,0,.2,1)` | 100 ms, same curve | settles in 0.100 s | met — driven at 1 kHz |
| toggle | off | bg `#292524` @ **0.10**, knob x 0 | same | ref delta 0.64 %, clone 0.65 %; agree to **0.14 %** | met — sourced by clicking the live reference |
| toggle | on↔off | track 220 ms ease-out; knob 220 ms `ease` | same | settles 0.220 s both | met |
| toggle | `:focus-visible` | ring 2px `#292524` @ 0.20 | same | ref delta 0.24 %, clone 0.26 %; agree to **0.10 %** | met — keyboard focus, not mouse |
| slider | drag | fill `width`, thumb `left`, 220 ms ease-out; the `left` transition is **dropped** once travel exceeds 3 px so the thumb tracks the pointer | same | settles 0.220 s | met — drag rule read from the reference's own handler |
| slider | thumb press | `scale-110` (CSS `scale: 1.1`), `transition-[scale,box-shadow]` 220 ms ease-out | same | ref delta 0.08 %, clone 0.06 %; agree to **0.02 %** | met — **now sourced** by holding the pointer on the live thumb |
| slider | value 40 % | fill 40 %, thumb left `calc(40 % + 0.125rem)` | same | ref delta 0.75 %, clone 0.73 %; agree to **0.01 %** | met — second sample point, which is what exposed the formula bug |
| panel | present / dismiss | — | none implemented | — | **UNSOURCED** |
| popover | dark mode | — | not implemented | — | **UNSOURCED** (the site's dark theme is the page, not the app popover) |
| all | reduced motion | — | every transition collapses to 0 ms under `accessibilityDisplayShouldReduceMotion` | verified: `set()` lands on target with `isRunning == false` | met (inferred — platform requirement, not in the reference) |

---

## B — Switches panel  (ref rect 328 × 551 at page 176,664.5)

| element | property | reference | clone | Δ | status |
|---|---|---|---|---|---|
| panel | width × height | 328 × 551 | same | 0 | met |
| panel | radius / fill | 24; `#292524` @ 0.80 | same | 0 | met — empty regions max ∆ 2 |
| panel | top hairline | 1px `#fff7ed` @ 0.15 | same | 0 | met |
| panel | shadow | `0 25px 50px −12px rgba(28,25,23,.80)` | same | 0 | met |
| group hdr | box | pad-top 11 (first 10), margin-top 6, h 31 (first 30) | same | 0 | met |
| group hdr | label / rule | 14px/20 w600 `#fff7ed` @ 0.40; rule `/0.15` | same | 0 | met |
| switch row | box | 304 × 36, pad 6/12, radius 8, gap 2 | same | 0 | met |
| swatch | box / borders | 18², r6; top 1px `/0.35` over all-sides 1px `/0.15` | same | 0 | met |
| swatch | fill | vertical gradient, 7 measured stop pairs | same, keycap path with plus knocked out | 0 | met |
| name | type | 15px/22.5 w500 `#fff7ed`, x = swatch + 8 | same | 0 | met — widths within 0.27 px across all seven |
| "New" badge | box / label | r6, 1.5px `rgba(243,88,115,.75)`; 12px/16 w600 `/0.9` | same | 0 | met |
| play button | box | 24² circle, `/0.10`, top hairline `/0.15`, shadow-sm | same | 0 | met — bbox and centroid identical to **0.01 px** |
| play glyph | box | 14px, `/0.9`, +2 x | same | 0 | met |
| footer | ellipsis | 24px glyph, opacity .6, centred, row h 39 | same | 0 | met (it is an ellipsis, not a chevron) |
| rows | order | CherryMX·Japanese Black / Everglide·Crystal Purple·Oreo / Flurples·Cardboard / Gateron·Milky Yellow / Keychron·Super Red(New) / NovelKeys·Cream | same | 0 | met |

### B — states

| element | state | reference | clone | Δ | status |
|---|---|---|---|---|---|
| switch row | `:hover` | bg `#fff7ed` @ 0.10, 100 ms ease-out | same | ref delta 5.66 %, clone 5.61 %; agree to **0.19 %** | met — triggered and diffed |
| preview label | `:hover` | opacity 0→1, translateX 4→0, **150 ms** ease-in-out | same | included in the above | met — 150 ms sourced, was wrong at 100 ms |
| play button | `:hover` | `/0.10` → `/0.15`, 150 ms ease-in-out | same | included in the above | met |
| row | playing | glyph swaps play → **rounded-square stop**, 150 ms `opacity-0 scale-50` out-in; stop square carries `animate-pulse`; the Preview label is suppressed | same (pulse held at its 0 % phase for capture) | ref delta 5.66 %, clone 5.61 %; agree to **0.12 %** | met — **now sourced** by clicking a play button on the live reference |
| row | selected | — | not implemented | — | **UNSOURCED** (mockup shows no selected row) |
| panel | scroll / overflow | ellipsis implies more content | list is fixed; no scrolling | — | **UNSOURCED** |

---

## C — Native chrome (desktop.md rows)

| row | reference / expectation | clone | status |
|---|---|---|---|
| presentation | custom translucent panel, not a stock `NSMenu` | `NSPanel`, borderless + nonactivating, level 25 (`.statusBar`) | met (shape inferred from the mockup: 24pt radius, blur, hairline) |
| window chrome | none | `titlebar=none`, `isOpaque=false`, `hasShadow=false` (shadow is drawn per the ledger) | met |
| traffic lights | n/a — borderless | n/a | met |
| corner radius | 24 | 24 | met |
| window size | popover 288 × 370.5 content | window 368 × 451 = content + drawn-shadow margin | met |
| app menu / Dock icon | accessory app | `activationPolicy = 1` (`.accessory`): no Dock icon, no app menu | met |
| menu-bar icon | "K" keycap glyph | `NSStatusItem` 34 × 22, template image = true | met — could not be photographed: Alcove occupies the menu bar on this Mac |
| backdrop, shipping window | `backdrop-filter: blur(24px)` | `NSVisualEffectView(.underWindowBackground)` + the same 80 % fill | **partial** — see note |
| min/max size, resize | fixed-size panels | fixed | met |
| ⌥⌘K toggle, ⌘, settings, ⌘Q quit | from the v1.2.1 menu capture | bound on the panel; `Klack --keys` asserts all six mappings including the two negatives (⌘K and bare K map to nothing) | met — shortcuts are v1-sourced, the v2 popover never shows them |
| Esc to dismiss | — | bound | inferred (platform convention, not in the reference) |
| launch at login | — | — | **UNSOURCED** |
| settings window | see **surface D** below | built, sidebar + Sound pane | **now sourced** — a 2026 review video shows the v2 window |
| onboarding / Accessibility permission | required, per the FAQ | not implemented | **UNSOURCED** |

**Backdrop note — CLOSED.** This was the weakest row; it is now measured, and
the gap is gone.

`Klack --stage-onscreen` puts the reference page composition on screen, floats
the **real** `SurfacePanel`s over it at the reference offsets, and lets
`screencapture` measure the shipping path end to end. On-screen capture floor
(same stage captured twice): **0.00 %** both surfaces.

| shipping path | popover | switches |
|---|---|---|
| `NSVisualEffectView`, best of 14 materials × 2 appearances | 51.61 % | 46.08 % |
| calibrated Gaussian over a live backdrop | **1.09 %** | **2.08 %** |
| the offscreen harness, for comparison | 1.07 % | 1.97 % |

So the shipping window now renders what the harness verifies, to within
0.02–0.11 points.

Getting there needed four fixes, each found by measurement:

1. **No AppKit material can do it.** All 28 configurations were swept
   (`tools/material-sweep.sh`); every material re-tints and de-saturates the
   backdrop, and none gets below 46 % differing. `hudWindow` (light for the
   popover, dark for the switches panel) is the measured best and is the
   fallback. This is evidence the vendor's mockup is a stylised depiction:
   `backdrop-filter: blur(24px)` is not reachable with standard vibrancy.
2. **`SCContentFilter` excluded too much.** Excluding every window the app owns
   also excluded the stage's own backdrop window, so the capture returned the
   user's real desktop — 82.9 % differing. Excluding only the panels: 3.19 %.
3. **Window origin rounding.** The popover window is 450.5 pt tall, so AppKit
   rounded its origin and put the whole panel one device pixel off — 2.75 %
   against the verified render, collapsing to 0.05 % under a +1 px shift.
   Windows are now rounded up to whole points, and `PanelHostView` carries the
   sub-point remainder so content lands on the intended device pixel wherever
   the window is placed. The switches panel had the same fault from its
   half-point y and is fixed by the same change.
4. **Permission is not demanded.** `CGPreflightScreenCaptureAccess()` answers
   without prompting, so the calibrated path is used when screen access is
   already granted and the material fallback otherwise. A keyboard-sound app
   should not ask for screen recording to match a blur radius.

Two materials were also compared for correctness of construction:
`.popover`/`.hudWindow` tint the panel a second time on top of the 80 % fill the
ledger already specifies, so the fallback lets the specified fill do the
tinting.


---

## D — Settings window  (618 × 645 pt, sidebar 224 pt)

Found after the first pass reported this row UNSOURCED. Three sources turned up
on a second research sweep:

| source | what it gives | grade |
|---|---|---|
| 2026 review video, frames 47–53 s and 68–72 s (2560×1440) | the **current v2 window**, Sound pane, two scroll positions | **primary** |
| tsamoudakis.com, Mar 2025 — `023-klack-settings-{general,sound}.png` | the **pre-Tahoe** settings window: a 4-tab toolbar, completely different | superseded, but confirms which panes existed |
| macsales.com, Feb 2025 — `Klack_Settings.jpg` | same superseded design | corroboration |

The 2025 screenshots are a tab-bar window; the 2026 video is a sidebar window.
The App Store notes "a complete redesign to fit macOS Tahoe", so the video is
the current design and the 2025 shots are the old one. Cloned the video.

**Scale recovery.** The video is a rescaled screen recording, so its scale had
to be recovered rather than assumed. macOS 26 spaces window buttons 23 pt apart
(measured on this machine with `NSWindow.standardWindowButton`); the frame
measures 44.75 px between centres, giving **1.946 px/pt**. Every metric below is
a frame measurement divided by that.

**No pixel gate.** The reference is a compressed video frame of a translucent
window over an unknown desktop. Colour cannot be recovered — the app's own teal,
which is exactly `(0,187,167)`, reads `(102,221,205)` through the window over a
bright wallpaper. So this surface is verified by **geometry**, measured the same
way in both images with `tools/measure-settings.py`.

| element | reference (pt) | clone (pt) | Δ |
|---|---|---|---|
| toggle 1 centre y | 94.5 | 94.5 | **0.0** |
| toggle 2 centre y | 136.5 | 136.2 | **−0.3** |
| toggle 3 centre y | 178.3 | 178.3 | **0.0** |
| toggle left edge | 547.8 | 547.3 | **−0.5** |
| toggle size | 43.2 × 20.0 | 43.1 × 20.0 | **0.1 × 0.0** |
| toggle row pitch | 42.0 / 41.8 | 41.7 / 42.1 | **≤ 0.3** |
| sidebar Stats tile centre y | 344.9 | 345.1 | **+0.2** |
| sidebar tile left edge | 21.6 | 21.6 | **0.0** |
| Sound Effects slider centre y | 619.1 | 618.2 | **−0.9** |
| Sound Effects track left edge | 253.9 | 253.9 | **0.0** |

Worst positional Δ **0.9 pt**; everything else ≤ 0.5 pt.

### Shipping window verified on screen

The window was then launched for real and captured off the display. Its origin
was solved from the capture rather than assumed (the close button sits 8 pt
below the window top on a `fullSizeContentView` window with a hidden title, not
the 16 pt a standard titlebar gives). Measured against the offscreen render that
the table above verifies:

| element | Δ centre y | Δ left | Δ height |
|---|---|---|---|
| Sound toggle | −0.1 | 0.0 | 0.0 |
| Volume slider | 0.0 | 0.0 | 0.0 |
| sidebar selection + Sound tile | 0.0 | 0.0 | 0.0 |
| Stereo panning toggle | 0.0 | 0.0 | 0.0 |
| Spatial audio toggle | 0.0 | 0.0 | 0.0 |

**0.0 pt** everywhere. What ships is what was measured. The real window adds
AppKit's traffic lights and live `NSVisualEffectView` vibrancy over whatever is
behind it; the flat ground in the verify render is only there to keep geometry
measurable.

### Sourced

- Sidebar: General / *Settings*: Sound, Sleep, Visualizer (dimmed, "Soon" pill), Notifications / *Klack*: Stats, About. Item pitch a clean 38 pt across all six gaps.
- Sound pane, in order: **Sound** toggle, **Volume** slider, **Play sound through** popup · *Profile*: **Switch sound** popup (swatch + name + chevrons), **Stereo panning**, **Spatial audio** (trailing glyph), **Pitch variation**, **Ignore rapid key events**, **Disable audible modifier keys** · *Tone Pad*: dot grid with a lit cross through a draggable knob, half-filled circle control at the group's right · *Sound Effects*: **Effects volume**.
- Slider rows are two lines — label + value pill, then a full-width track with a tick strip — measured at label +20.5, track +48.5, ticks +56.5 from the card top.
- The toggles are the app's own switch, not `NSSwitch`: 43.2 × 20.0 pt measured here against 44 × 20 measured on the popover.

### UNSOURCED

- **General, Visualizer, Notifications, About.** Still nothing published. They render an explicit "not published in any reference" placeholder rather than invented settings.
- **Sleep** — sourced and **built**, see surface F.
- **Stats** — see below.
- Icon tile **values** (hues are legible, exact colours are not — see the teal example above); platform palette used.
- ~~Light appearance~~ — **now sourced**: basicappleguy.com's "Apps of May 2026" carries a 1464 × 1516 light-mode capture of the same window (`ref/press/bag-klack.png`). It also shows the master **Sound** toggle rendering in the *system accent* colour while the Profile toggles stay Klack teal, and "Play sound through" naming the actual device ("MacBook Air"). Not yet built — the clone is dark-only.
- Window resize behaviour, minimum size, scroll bar styling.


---

## E — Stats pane

**Content sourced, layout inferred — and the two are worth keeping apart.**

The app's own Stats screen has never been published: the 2026 review video opens
Sound and Sleep and nothing else, and no review, listing or screenshot library
has it. But the same developer ships a **Raycast extension** whose "Klack Stats"
screenshot reads Klack's own data
(`ref/press/ray-pq6fgs4s5nwudjxn7ammiq2awppi.png`), and that fixes the data
model exactly.

| sourced from the Raycast extension | inferred |
|---|---|
| section "Total Usage" and the "Tracking since Apr 30, 2026" line | the arrangement of those elements in the app's pane |
| metrics and their order: **Keystrokes**, **Dings**, **Clicks** | — |
| values 474,961 / — / 517, and that an absent metric shows an em dash | — |
| section "Favourite Switches", ranked, with per-switch counts | — |
| Super Red 474,956 · Japanese Black 4 · Cream 1, each with its keycap swatch | — |
| that the top-ranked switch is emphasised | the emphasis being Klack's rose rather than Raycast's accent |

Everything drawn is the app's **own measured chrome**, not new invention:
41.9 pt rows, 10 pt cards, 12 pt hairline insets, 13 pt labels, the "100 %"
value pill from the Sound pane, and the 18 pt gradient keycap swatch measured on
the switches panel. So the pane is built out of sourced parts even where its
composition is a judgement call.

**Not verifiable by diff.** There is no image of this pane to diff against. The
row metrics are identical to the Sound pane by construction (same constants),
which is the only claim available and is a weaker one than every other surface
here carries. If a capture of the real Stats pane ever surfaces, this is the
first row to re-check.


---

## F — Sleep pane

Sourced from the same review video at **104–110 s**, which the first pass's 2 s
frame sampling stepped straight over. Measured at 1.946 px/pt off
`ref/video/winSleep.png`.

| element | reference (pt) | clone (pt) | Δ |
|---|---|---|---|
| master toggle centre y | 74.4 | 74.0 | −0.4 |
| master toggle left | 548.8 | 547.3 | −1.5 |
| Volume track centre y | 149.8 | 149.5 | −0.3 |
| Volume track left | 253.9 | 253.9 | **0.0** |
| sidebar Sleep tile centre y | 345.3 | 345.1 | −0.2 |
| Focus checkbox centre y | 400.1 | 400.8 | +0.7 |
| Focus checkbox left | 253.9 | 253.9 | **0.0** |

The 1.5 pt on the toggle's left edge is frame noise: the same control measures
547.8 in the Sound-pane frame, which the clone matches.

### What this pane taught the Sound pane

The Sleep pane's master row resolved a layout question the Sound pane could not.
Its toggle measures at centre 74.4 pt (card top + 20.95) while the Volume track
below measures at 149.8 pt — and only a **47.8 pt row with 41.9 pt of
top-aligned content** satisfies both. The Sound pane has the same icon-led
master row, and the clone had been drawing it without its leading icon at all.
Both are now fixed.

### Sourced

- Card 1: **Sleep** master toggle (icon-led) and **Volume**.
- Section **Sleep Triggers** with a small round control at its right.
- Ten triggers, in order, each a checkbox + app-style icon tile + label:
  Bluetooth · Calendar Event · Camera · External Keyboard · **Focus ▸ Any**
  (the only one checked) · Headphones · Microphone · **Now Playing ▸ Any** ·
  Screen Sharing · Speakers.
- Trigger rows share the Sound pane's 41.9 pt pitch; checkbox 14 pt at x 253.9.

### UNSOURCED / noted

- **The Volume slider is not linear.** The frame shows the knob at ~66 % of the
  track while the badge reads **20 %**. Rather than guess the curve, the clone
  reproduces the measured knob position and the measured label, and this stays
  a recorded observation rather than a model.
- Bluetooth has no SF Symbol (Apple does not ship the trademark), so the tile
  uses `antenna.radiowaves.left.and.right`. Icon tile hues are read off the
  frame; their exact values are not recoverable through the translucency.
- The trailing glyphs on the Bluetooth and Calendar rows are legible in the
  frame but too small to identify; not drawn.


---

## G — Behaviour: usage tracking and sleep triggers

Both panes now read and write real state instead of rendering constants.

### Usage tracking

Counts key-downs (modifiers excluded), mouse clicks and return-key dings,
attributes every keystroke to the switch that was loaded, and persists to
`~/Library/Application Support/KlackClone/usage.json`. Verified across two
processes:

| | after reset | after 275 simulated keystrokes (process A) | re-read in process B |
|---|---|---|---|
| Keystrokes | — | 275 | **275** |
| Clicks | — | 3 | **3** |
| Super Red | — | 250 | **250** |
| Japanese Black | — | 25 | **25** |

Zero renders as an em dash, matching the Raycast extension's formatting of an
absent metric. The `--settings-verify --pane stats` render seeds the reference
numbers instead, so the geometry row above stays reproducible; `--live` shows
real counts.

### Sleep triggers

The trigger list and its order are sourced. **How Klack detects each condition
is not published**, so every detector is mine — and three of ten cannot be read
honestly on macOS 26:

| trigger | detector | reading here |
|---|---|---|
| Bluetooth | `system_profiler SPBluetoothDataType`, 30 s cache | **ACTIVE** |
| Speakers | CoreAudio default output transport + data source | **ACTIVE** |
| Headphones | same, complementary branch | inactive |
| External Keyboard | IOKit HID: any keyboard on USB/Bluetooth vs the built-in FIFO one | inactive — correct, only "Apple Internal Keyboard / Trackpad" on FIFO is present |
| Camera | `AVCaptureDevice.isInUseByAnotherApplication` | inactive |
| Microphone | same, audio devices | inactive |
| Screen Sharing | `screensharingd` / `ScreensharingAgent` / `AppleVNCServer` in the process list | inactive |
| Calendar Event | EventKit, access requested only when the trigger is enabled | **unavailable** — not granted |
| Focus | — | **unavailable** — no public API on macOS 26 |
| Now Playing | — | **unavailable** — needs the private MediaRemote framework |

When an enabled trigger reads active, `SoundEngine.suppressed` goes true and the
app falls silent while staying configured.

**Focus is worth calling out.** It is the one trigger the reference shows
switched *on*, and it is the one that cannot be read: older macOS kept active
modes in `~/Library/DoNotDisturb/DB/Assertions.json`, that directory no longer
exists on macOS 26, and `com.apple.donotdisturbd.plist` holds only CloudKit
cache keys. The detector reports unavailable rather than guessing.

Two dead ends before Bluetooth worked, both worth recording:
`IOBluetoothHostController` blocks on a CoreBluetooth coordinator that needs a
running run loop — called before `NSApp.run()` it deadlocks and the process is
killed — and `com.apple.Bluetooth.plist` no longer carries
`ControllerPowerState`.

```
Klack --triggers          # read every detector live
Klack --usage             # print the store
Klack --usage --reset
Klack --usage --simulate 250
Klack --settings-dump     # every persisted setting, and which are not wired
Klack --settings-dump --reset
Klack --set volume 0.35   # volume switch pitch panning spatial rapid modifiers tone
```

### Settings persistence

Every row the panes expose is backed by `Settings` and written to
`~/Library/Application Support/KlackClone/settings.json`. Verified the same way
as usage — change in one process, read in another:

| | after reset | changed (process A) | re-read in process B |
|---|---|---|---|
| Volume | 70 % | 35 % | **35 %** |
| Switch | 0 — Japanese Black | 5 — Super Red | **5 — Super Red** |
| Pitch variation | on | off | **off** |
| Ignore rapid key events | off | on | **on** |
| Tone Pad | x 0.50 y 0.50 | x 0.25 y 0.80 | **x 0.25 y 0.80** |

The Sound and Sleep panes now render from this store rather than from constants,
and their rows are interactive: toggles flip, the volume and effects sliders
drag, the Tone Pad knob drags, and "Switch sound" cycles the catalogue.

**Reaching the engine, not just the file.** With the variant randomiser disabled
so the measurement isolates one variable, the Tone Pad's x axis moves the audio
as intended:

| Tone Pad x | first event | spectral centroid |
|---|---|---|
| 0.10 | 33.6 ms | 7384 Hz |
| 0.50 | 31.2 ms | 8124 Hz |
| 0.90 | 29.1 ms | 8162 Hz |

Duration ratio 1.155 against 1.137 predicted from the rate change — the setting
is doing what it says.

**Interpretations, flagged as such.** The reference shows these controls but not
their meaning, so: *Spatial audio* widens the stereo field (×1.55), *Tone Pad* x
is read as a pitch-centre offset and y as a level trim, and *Ignore rapid key
events* drops a down within 25 ms of the previous one.

### Play sound through

Real device routing. `AudioDevices` enumerates every output device with output
channels, and the selection is applied by setting
`kAudioOutputUnitProperty_CurrentDevice` on the engine's output unit — which
only takes while the engine is stopped, so `setOutput` cycles it. `--devices`
reads the property back, which is the only way to confirm the route took rather
than assume it:

```
output devices:
  MacBook Pro Speakers              id 71   (system default)
setting: System output
engine is on: MacBook Pro Speakers
```

Two things the read-back caught. CoreAudio publishes a **private per-client
aggregate** whose name carries the pid and changes every launch
(`CADefaultDeviceAggregate-68081-0` became `…-68148-0` one run later), so a
stored selection could never match it again — hidden devices and those
aggregates are filtered out of the picker. And a stored name that no longer
resolves falls back to the system default rather than going silent, because a
device can be unplugged between runs.

### Effects volume

Scales the return-key ding and the mouse click, leaving keystrokes on the main
Volume — the Sound tab's own "effects" are exactly those two rows.

Measuring it needed care: the ding shares the spectrum with the keystroke
recordings, which are broadband. Isolating the ding's 1318.5 Hz partial and
subtracting the keystroke floor measured in the same band at 0 %:

| Effects volume | dB vs 100 % | expected | error |
|---|---|---|---|
| 100 % | 0.00 dB | 0.0 | — |
| 50 % | −6.11 dB | −6.0 | −0.11 |
| 25 % | −10.86 dB | −12.0 | +1.14 |

The 25 % case sits close to the keystroke floor, which is where the 1.1 dB comes
from. Two earlier attempts at this measurement were wrong and worth recording: a
first pass measured peak level and read ±0.3 dB because the **peak limiter** was
flattening the differences, and a second forced the master volume to 0 to
isolate the ding, which made every player gain 0 — the numbers that came back
were a stale file from a `mv` that had silently failed.

`Settings.notWired` is now empty: every row the panes expose reaches the engine.


---

## H — Switch sample quality

Asked whether the site's own preview clips could be used instead. They cannot:
those buttons play Klack's actual sample library, which is the product. Nothing
in this clone comes from tryklack.com.

What the question did surface is that the samples **were** poor, for a reason
measurement found rather than listening:

| | before | after |
|---|---|---|
| slices containing a second keystroke | **16 / 70** | **0 / 70** |
| variants per switch per direction | 10 | 10 |
| Super Red noise floor | −14.7 dB | **−31.3 dB** |
| worst noise floor across sets | −14.6 dB | −24.4 dB |
| worst peak in a typing burst | 0.782 | 0.851 (no clipping) |

Nearly a quarter of the library was a **double-tap** — the extraction took the
ten loudest strokes per switch without checking whether the 95 ms window ran into
the next keystroke. Fixed by requiring silence before a candidate, **sizing each
window to the gap actually available** instead of a fixed length, and discarding
any slice that still shows a second transient. Sizing rather than rejecting is
what keeps a full ten variants on the dense recordings — an earlier attempt that
only rejected left Milky Yellow with two.

**Super Red** was also re-sourced. Its WhiteFox / Hako Violet recording carried
an audible hiss once the set was loudness-matched; the Ducky X Varmilo recording
measures 16.6 dB cleaner. Provenance for all seven is in
`assets/switches/CREDITS.md`.


---

## I — Crispness

"Crisp" made measurable as four numbers on the down-strokes: **10-90 % attack
time**, **crest factor**, **share of energy above 4 kHz**, and **share below
150 Hz** (rumble, which muddies rather than adds).

| | before | after |
|---|---|---|
| attack, median | 1.34 ms | **0.48 ms** |
| energy above 4 kHz | 9.0 % | **20.5 %** |
| energy below 150 Hz | 28.1 % | **9.2 %** |
| crest factor | 12.2 | 12.8 |
| worst peak, 110 ms typing | 0.99 | **0.51–0.58** |
| worst peak, 35 ms burst (~340 wpm) | 1.55 | **0.83** |
| clipped samples, any speed | many | **0** |

Four causes, each found by measurement rather than listening:

1. **A 1.2 ms fade-in on a click.** Applied to stop slices starting on a step, it
   was rounding off the very edge that makes a keystroke snap. Cut to 0.15 ms,
   and the window now starts 0.6 ms before the onset instead of 4 ms.
2. **28 % of the energy was below 150 Hz** — room rumble from the source
   recordings, not switch. A 120 Hz high-pass takes it to 9 %.
3. **Only 9 % above 4 kHz.** The sources are 160–236 kbps MP3 previews and lose
   the top. A +4 dB shelf above 4 kHz restores some of it.
4. **Linear interpolation in the pitch-variation resampler**, which is a crude
   low-pass — and every keypress goes through it. Now Catmull-Rom.

### The limiter had to be written, not configured

Neither Apple effect would hold the sum. **AUPeakLimiter** measured peaks going
*up* (Cream 0.866 bypassed → 1.044 with it) and still let a fast burst reach
1.26. **AUDynamicsProcessor** at −6 dBFS threshold let it reach 1.53 — the graph
and its parameters were verified correct, so it was behaving as a compressor
with makeup rather than a ceiling. And headroom alone was not available:
ordinary 110 ms typing already peaked at 0.99.

So the player-node-per-voice design was replaced with a single
`AVAudioSourceNode` and an own mixer: a 32-voice pool, Catmull-Rom resampling,
equal-power panning, and a true brickwall (instantaneous attack, ~50 ms release)
that sees every sample of the sum. Triggers reach the audio thread through a
lock-free single-producer ring, so the render path neither allocates nor locks.
Worst peak across every switch at 110/75/60/35 ms spacing is now **0.834**
against a 0.95 ceiling, with zero clipped samples.

### The Crystal Purple outlier, chased

It was **one slice out of ten**, not a property of the set. `down_06` had its
transient 10.3 ms into the window with 60 % of its energy ahead of it — the
onset detector had fired on something quiet and the click arrived later. The
other nine peaked at 0.27–0.94 ms. Because the engine picks a variant at random,
that single take was enough to make the whole set measure at 11 ms.

The first fix was wrong and worth recording: **re-aligning every slice to its own
transient** made all seven sets worse (mean attack 0.61 → 1.18 ms), because the
walk-back from the peak runs a long way up a slow ramp and so starts the slice
even earlier. Reverted.

What worked was smaller — **reject any slice whose transient arrives more than
3 ms in**. One take dropped, nothing else disturbed:

| | before | after |
|---|---|---|
| Crystal Purple attack | 1.25 ms | **0.26 ms** |
| Crystal Purple, through the engine | 11.12 ms | **0.44 ms** |
| worst single slice, any switch | 10.12 ms | **1.92 ms** |
| mean attack, all sets | 0.61 ms | **0.47 ms** |
| variants retained | 140 | 139 |

Peaks and clipping are unchanged: worst 0.828 under a 340 wpm burst, zero
clipped samples.
