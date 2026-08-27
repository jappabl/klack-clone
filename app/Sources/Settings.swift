import Foundation

/// Everything the UI can change, persisted.
///
/// The *rows* are sourced — the review video shows exactly which settings exist
/// and in what order. How Klack stores them is not published, so this uses the
/// same plain JSON file approach as `UsageStore`.
///
/// A few rows are stored and rendered but do not yet reach the engine; those are
/// marked below rather than quietly pretending. `Klack --settings-dump` prints
/// the live values and flags them.
final class Settings {

    static let shared = Settings()

    // popover / Sound pane
    var enabled = true                     { didSet { changed() } }
    var volume: Double = 0.70              { didSet { changed() } }
    var switchIndex = 0                    { didSet { changed() } }
    var playSoundThrough = "System output" { didSet { changed() } }
    var stereoPanning = true               { didSet { changed() } }
    var spatialAudio = true                { didSet { changed() } }
    var pitchVariation = true              { didSet { changed() } }
    var ignoreRapidKeyEvents = false       { didSet { changed() } }
    var disableAudibleModifiers = false    { didSet { changed() } }
    var tonePad = CGPoint(x: 0.5, y: 0.5)  { didSet { changed() } }
    var effectsVolume: Double = 1.0        { didSet { changed() } }
    var mouseClickSounds = false           { didSet { changed() } }
    var dingOnReturn = false               { didSet { changed() } }

    // Sleep pane
    var sleepEnabled = true                { didSet { changed() } }
    var sleepVolume: Double = 0.662        { didSet { changed() } }
    var sleepTriggers: Set<String> = ["Focus"] { didSet { changed() } }

    /// Rows persisted and shown but not acted on by the engine. Empty now.
    static let notWired: [String] = []

    private let url: URL
    private var loading = false

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("KlackClone", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("settings.json")
        load()
    }

    var path: String { url.path }

    /// Launch diagnostics, next to the settings file.
    func log(_ text: String) {
        let f = url.deletingLastPathComponent().appendingPathComponent("launch.log")
        try? text.appending("\n").write(to: f, atomically: true, encoding: .utf8)
    }

    private func changed() {
        guard !loading else { return }
        apply()
        save()
    }

    /// Push the current values into the audio side.
    func apply() {
        let e = SoundEngine.shared
        e.enabled = enabled
        e.volume = Float(volume)
        e.pitchVariation = pitchVariation
        e.stereoPanning = stereoPanning
        e.spatialAudio = spatialAudio
        e.muteModifiers = disableAudibleModifiers
        e.dingOnReturn = dingOnReturn
        e.mouseClickSounds = mouseClickSounds
        e.ignoreRapidKeys = ignoreRapidKeyEvents
        e.effectsVolume = Float(effectsVolume)
        e.setOutput(playSoundThrough)
        e.toneOffset = Float(tonePad.x - 0.5)      // see SoundEngine.toneOffset
        e.toneTrim = Float(0.5 - tonePad.y)
        if e.switchIndex != switchIndex { e.switchIndex = switchIndex }
        SleepTriggers.shared.enabled = sleepTriggers
    }

    // MARK: persistence

    private struct Blob: Codable {
        var enabled: Bool; var volume: Double; var switchIndex: Int
        var playSoundThrough: String
        var stereoPanning: Bool; var spatialAudio: Bool; var pitchVariation: Bool
        var ignoreRapidKeyEvents: Bool; var disableAudibleModifiers: Bool
        var tonePadX: Double; var tonePadY: Double; var effectsVolume: Double
        var mouseClickSounds: Bool; var dingOnReturn: Bool
        var sleepEnabled: Bool; var sleepVolume: Double; var sleepTriggers: [String]
    }

    private func load() {
        guard let d = try? Data(contentsOf: url),
              let b = try? JSONDecoder().decode(Blob.self, from: d) else { return }
        loading = true
        enabled = b.enabled; volume = b.volume; switchIndex = b.switchIndex
        playSoundThrough = b.playSoundThrough
        stereoPanning = b.stereoPanning; spatialAudio = b.spatialAudio
        pitchVariation = b.pitchVariation
        ignoreRapidKeyEvents = b.ignoreRapidKeyEvents
        disableAudibleModifiers = b.disableAudibleModifiers
        tonePad = CGPoint(x: b.tonePadX, y: b.tonePadY)
        effectsVolume = b.effectsVolume
        mouseClickSounds = b.mouseClickSounds; dingOnReturn = b.dingOnReturn
        sleepEnabled = b.sleepEnabled; sleepVolume = b.sleepVolume
        sleepTriggers = Set(b.sleepTriggers)
        loading = false
    }

    func save() {
        let b = Blob(enabled: enabled, volume: volume, switchIndex: switchIndex,
                     playSoundThrough: playSoundThrough,
                     stereoPanning: stereoPanning, spatialAudio: spatialAudio,
                     pitchVariation: pitchVariation,
                     ignoreRapidKeyEvents: ignoreRapidKeyEvents,
                     disableAudibleModifiers: disableAudibleModifiers,
                     tonePadX: tonePad.x, tonePadY: tonePad.y,
                     effectsVolume: effectsVolume,
                     mouseClickSounds: mouseClickSounds, dingOnReturn: dingOnReturn,
                     sleepEnabled: sleepEnabled, sleepVolume: sleepVolume,
                     sleepTriggers: Array(sleepTriggers).sorted())
        if let d = try? JSONEncoder().encode(b) { try? d.write(to: url, options: .atomic) }
    }

    func reset() {
        loading = true
        enabled = true; volume = 0.70; switchIndex = 0
        playSoundThrough = "System output"
        stereoPanning = true; spatialAudio = true; pitchVariation = true
        ignoreRapidKeyEvents = false; disableAudibleModifiers = false
        tonePad = CGPoint(x: 0.5, y: 0.5); effectsVolume = 1.0
        mouseClickSounds = false; dingOnReturn = false
        sleepEnabled = true; sleepVolume = 0.662; sleepTriggers = ["Focus"]
        loading = false
        apply(); save()
    }

    var dump: String {
        var l: [String] = []
        func row(_ k: String, _ v: String) {
            let flag = Settings.notWired.contains(k) ? "   (stored, not wired to the engine)" : ""
            l.append("  " + k.padding(toLength: 26, withPad: " ", startingAt: 0) + v + flag)
        }
        row("Sound", enabled ? "on" : "off")
        row("Volume", String(format: "%.0f%%", volume * 100))
        row("Switch", "\(switchIndex) — \(SoundEngine.shared.loadedName)")
        row("Play sound through", playSoundThrough)
        row("Stereo panning", stereoPanning ? "on" : "off")
        row("Spatial audio", spatialAudio ? "on" : "off")
        row("Pitch variation", pitchVariation ? "on" : "off")
        row("Ignore rapid key events", ignoreRapidKeyEvents ? "on" : "off")
        row("Disable audible modifiers", disableAudibleModifiers ? "on" : "off")
        row("Tone Pad", String(format: "x %.2f  y %.2f", tonePad.x, tonePad.y))
        row("Effects volume", String(format: "%.0f%%", effectsVolume * 100))
        row("Sleep", sleepEnabled ? "on" : "off")
        row("Sleep volume", String(format: "%.0f%%", sleepVolume * 100))
        row("Sleep triggers", sleepTriggers.sorted().joined(separator: ", "))
        return l.joined(separator: "\n")
    }
}
