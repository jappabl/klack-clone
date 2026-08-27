import AppKit

/// Surface D — the Settings window (Klack v2, the macOS Tahoe redesign).
///
/// Reference: a 2026 review video, frames 47–53 s and 68–72 s
/// (`ref/video/klack-2026.webm`, 2560×1440). Scale was recovered from the
/// traffic lights: macOS 26 spaces them 23 pt apart and the frame measures
/// 44.75 px between centres, so the frame is **1.946 px/pt**.
///
/// The video only ever shows the **Sound** pane. The sidebar proves the other
/// six exist and gives their titles, icons and order; their contents are
/// UNSOURCED and are left as explicit placeholders rather than invented.
enum SettingsPane: String, CaseIterable {
    case general, sound, sleep, visualizer, notifications, stats, about

    var title: String {
        switch self {
        case .general: "General"; case .sound: "Sound"; case .sleep: "Sleep"
        case .visualizer: "Visualizer"; case .notifications: "Notifications"
        case .stats: "Stats"; case .about: "About"
        }
    }
    /// SF Symbols chosen to match the glyphs legible in the frame.
    var symbol: String {
        switch self {
        case .general: "gearshape.fill"; case .sound: "speaker.wave.2.fill"
        case .sleep: "moon.zzz.fill"; case .visualizer: "command"
        case .notifications: "bell.badge.fill"; case .stats: "chart.bar.fill"
        case .about: "info.circle.fill"
        }
    }
    /// Tile hues are readable in the frame; the exact values are not, because
    /// every tile is sampled through the window's translucency over a bright
    /// wallpaper (the teal toggle reads (102,221,205) where the app's own
    /// measured teal is (0,187,167)). Hue sourced, value from the platform.
    var tile: NSColor {
        switch self {
        case .general:       return T.srgb(142, 142, 147)   // grey
        case .sound:         return T.srgb(219,  62, 214)   // magenta
        case .sleep:         return T.srgb( 94,  92, 230)   // indigo
        case .visualizer:    return T.srgb( 72,  72,  74)   // near-black
        case .notifications: return T.srgb(255, 149,   0)   // orange
        case .stats:         return T.teal500                // matches the app's teal
        case .about:         return T.srgb(142, 142, 147)   // grey
        }
    }
    /// "Visualizer" is dimmed and carries a "Soon" pill in the frame.
    var isComingSoon: Bool { self == .visualizer }

    static let sections: [(String?, [SettingsPane])] = [
        (nil,        [.general]),
        ("Settings", [.sound, .sleep, .visualizer, .notifications]),
        ("Klack",    [.stats, .about]),
    ]
}

/// Every constant below is a measurement off the frame, converted at 1.946 px/pt.
enum SettingsMetrics {
    static let windowW: CGFloat = 618          // 1202 px
    static let windowH: CGFloat = 645          // 1255 px
    static let sidebarW: CGFloat = 224         // divider at 465 px

    // sidebar — item pitch is a clean 38 pt across all six measured gaps
    static let itemH: CGFloat = 38
    static let firstItemCenterY: CGFloat = 73  // "General", 162 px
    static let headerToFirst: CGFloat = 32.9   // section header -> first item
    static let itemToHeader: CGFloat = 46.5    // last item -> next section header
    static let selInsetX: CGFloat = 11.3       // highlight left edge, 52 px
    static let selW: CGFloat = 201             // highlight width, 391 px
    static let selH: CGFloat = 32
    static let selRadius: CGFloat = 8
    static let tileSize: CGFloat = 20.5        // 40 px
    static let tileRadius: CGFloat = 5
    static let tileX: CGFloat = 21.6           // measured off the Stats tile
    static let labelX: CGFloat = 48.3          // 124 px
    static let sidebarFont: CGFloat = 13
    static let headerFont: CGFloat = 11

    // detail
    static let detailX = sidebarW
    static let titleCenterY: CGFloat = 25.7    // "Sound" header, 70 px
    static let groupX: CGFloat = 241.4         // 500 px
    static let groupW: CGFloat = 361           // 702 px
    static let rowH: CGFloat = 41.9            // 81.5 px pitch
    /// Slider rows are two lines: label+pill, then track+ticks. 84 pt measured
    /// on the Sound Effects card (label +25, track +53, ticks +61 from its top).
    static let sliderRowH: CGFloat = 84
    static let groupRadius: CGFloat = 10
    static let rowFont: CGFloat = 13
    static let sectionFont: CGFloat = 13
}

/// The Sound pane, transcribed row by row from the frame. Two frames were
/// needed: 48 s shows the pane scrolled to the top, 50 s shows it scrolled down
/// to the Tone Pad and Sound Effects.
enum SoundPane {
    enum Control {
        case toggle(Bool)
        case slider(CGFloat, badge: String?)
        case popup(String, swatch: NSColor?)
        case tonePad(CGPoint)
    }
    struct Row { let label: String; let control: Control; let trailingGlyph: String?
                 var leadingSymbol: String? = nil; var leadingTint: NSColor? = nil }
    struct Group { let header: String?; let rows: [Row]; let isPad: Bool }

    static var groups: [Group] { let S = Settings.shared; return [
        Group(header: nil, rows: [
            // the master row is icon-led and taller, 47.8 pt — measured on the
            // Sleep pane and confirmed by t=48 s and the light-mode capture
            Row(label: "Sound", control: .toggle(S.enabled), trailingGlyph: nil,
                leadingSymbol: SettingsPane.sound.symbol, leadingTint: SettingsPane.sound.tile),
            Row(label: "Volume", control: .slider(CGFloat(S.volume),
                    badge: "\(Int((S.volume * 100).rounded()))%"), trailingGlyph: nil),
            Row(label: "Play sound through", control: .popup(S.playSoundThrough, swatch: nil), trailingGlyph: nil),
        ], isPad: false),
        Group(header: "Profile", rows: [
            Row(label: "Switch sound",
                control: .popup(Catalog.groups.flatMap { $0.items }[S.switchIndex].name,
                                swatch: Catalog.groups.flatMap { $0.items }[S.switchIndex].top),
                trailingGlyph: nil),
            Row(label: "Stereo panning",     control: .toggle(S.stereoPanning),  trailingGlyph: nil),
            Row(label: "Spatial audio",      control: .toggle(S.spatialAudio),  trailingGlyph: "spatial"),
            Row(label: "Pitch variation",    control: .toggle(S.pitchVariation), trailingGlyph: nil),
            Row(label: "Ignore rapid key events",       control: .toggle(S.ignoreRapidKeyEvents), trailingGlyph: nil),
            Row(label: "Disable audible modifier keys", control: .toggle(S.disableAudibleModifiers), trailingGlyph: nil),
        ], isPad: false),
        Group(header: "Tone Pad", rows: [
            Row(label: "", control: .tonePad(S.tonePad), trailingGlyph: nil),
        ], isPad: true),
        Group(header: "Sound Effects", rows: [
            Row(label: "Effects volume", control: .slider(CGFloat(S.effectsVolume),
                    badge: "\(Int((S.effectsVolume * 100).rounded()))%"), trailingGlyph: nil),
        ], isPad: false),
    ] }
}


/// The Stats pane.
///
/// **Content is sourced, layout is inferred.** The app's own Stats screen has
/// never been published — the 2026 review video opens Sound and Sleep and
/// nothing else. But the developer also ships a Raycast extension that reads
/// Klack's stats, and its "Klack Stats" screenshot
/// (`ref/press/ray-pq6fgs4s5nwudjxn7ammiq2awppi.png`) shows the data model
/// exactly: the metric names, their order, the "Tracking since" line, and the
/// Favourite Switches ranking with per-switch counts.
///
/// So the numbers, labels, order and grouping below are sourced. The
/// arrangement is not: it reuses the grouped-row idiom measured off the Sound
/// pane rather than inventing a new one, because that is the app's own pattern.
enum StatsPane {
    struct Metric { let label: String; let value: String }
    struct SwitchUse { let name: String; let top: NSColor; let bottom: NSColor; let count: String }

    static let trackingSince = "Tracking since Apr 30, 2026"
    static let totals: [Metric] = [
        Metric(label: "Keystrokes", value: "474,961"),
        Metric(label: "Dings",      value: "—"),
        Metric(label: "Clicks",     value: "517"),
    ]
    static let favourites: [SwitchUse] = [
        SwitchUse(name: "Super Red",      top: Catalog.hex("#fb7185"), bottom: Catalog.hex("#e11d48"), count: "474,956"),
        SwitchUse(name: "Japanese Black", top: Catalog.hex("#878078"), bottom: Catalog.hex("#44403c"), count: "4"),
        SwitchUse(name: "Cream",          top: Catalog.hex("#fff3e6"), bottom: Catalog.hex("#fecf9a"), count: "1"),
    ]
}


/// The Sleep pane. Sourced from the same review video at 104–110 s, which the
/// first 2 s frame sampling stepped over.
///
/// Measured at 1.946 px/pt off `ref/video/winSleep.png`:
/// master toggle centre 74.4 pt (x 548.8–591.5, the same switch as everywhere
/// else); Volume track centre 149.8 pt starting at x 253.9; the checked Focus
/// box 14 pt at x 253.9, centre 400.1 pt; trigger pitch 41.9 pt, the same row
/// height as the Sound pane.
enum SleepPane {
    struct Trigger {
        let label: String; let symbol: String; let tint: NSColor
        var checked = false; var popup: String? = nil
    }
    /// The frame shows the knob near 63 % of the track while the badge reads
    /// 20 %, so the control is not linear. Rather than guess the curve, the
    /// clone reproduces the measured knob position and the measured label.
    static var volumeKnobFraction: CGFloat { CGFloat(Settings.shared.sleepVolume) }
    static var volumeLabel: String { "\(Int((Settings.shared.sleepVolume * 100).rounded()))%" }

    static let triggers: [Trigger] = [
        Trigger(label: "Bluetooth",        symbol: "antenna.radiowaves.left.and.right", tint: T.srgb( 10,132,255)),
        Trigger(label: "Calendar Event",   symbol: "calendar",        tint: T.srgb(255, 69,  58)),
        Trigger(label: "Camera",           symbol: "camera.fill",     tint: T.srgb( 72, 72, 74)),
        Trigger(label: "External Keyboard",symbol: "keyboard.fill",   tint: T.srgb(142,142,147)),
        Trigger(label: "Focus",            symbol: "moon.fill",       tint: T.srgb( 94, 92,230), checked: true, popup: "Any"),
        Trigger(label: "Headphones",       symbol: "headphones",      tint: T.srgb( 72, 72, 74)),
        Trigger(label: "Microphone",       symbol: "mic.fill",        tint: T.srgb(142,142,147)),
        Trigger(label: "Now Playing",      symbol: "play.fill",       tint: T.srgb(255, 69, 58), popup: "Any"),
        Trigger(label: "Screen Sharing",   symbol: "rectangle.on.rectangle", tint: T.srgb(175, 82,222)),
        Trigger(label: "Speakers",         symbol: "hifispeaker.fill", tint: T.srgb(142,142,147)),
    ]
    // measured column positions
    static let checkX: CGFloat = 253.9, checkSize: CGFloat = 14
    static let iconX: CGFloat = 278, iconSize: CGFloat = 18
    static let labelX: CGFloat = 308
    /// The master row is 41.9 pt of content with 5.9 pt of extra space beneath
    /// it before the divider: the toggle measures at centre 74.4 pt (= card top
    /// + 20.95) while the Volume track below measures at 149.8 pt, and only a
    /// taller row with top-aligned content satisfies both.
    static let masterRowH: CGFloat = 47.8
    static let masterContentH: CGFloat = 41.9
    static let card1Top: CGFloat = 53.5
    static let triggersCardTop: CGFloat = 212.4
}
