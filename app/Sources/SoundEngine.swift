import AVFoundation
import AppKit

/// The audio side of the clone.
///
/// **Where the sounds come from.** Klack's own switch sets are the paid product
/// — their FAQ calls each set "over 100 audio files ... recorded and mastered
/// individually" — so they are not reproduced here. Instead the app plays real
/// mechanical-switch recordings taken from **CC0 (public domain) uploads on
/// Freesound**, sliced into individual down- and up-strokes by
/// `tools/slice-switches.py`. Provenance for every file is in
/// `assets/switches/CREDITS.md`.
///
/// The mapping onto Klack's switch names is nominal: each CC0 recording was
/// picked because its character (clicky / linear / thocky) is the nearest
/// available match, not because it is that switch.
///
/// What is genuinely cloned is the *architecture*: separate down and up sounds,
/// several takes per direction chosen at random, pitch variation per keystroke,
/// stereo placement from the key's position on the keyboard, and a preloaded
/// buffer path so a keypress never waits on file I/O or a graph change.
final class SoundEngine {

    static let shared = SoundEngine()

    // state, driven by the UI
    var enabled = true
    /// Set by SleepTriggers: the app stays configured but goes quiet.
    var suppressed = false
    var volume: Float = 0.7
    var pitchVariation = true
    var stereoPanning = true
    var muteModifiers = false
    var dingOnReturn = false
    var switchIndex = 0 { didSet { if switchIndex != oldValue { load() } } }
    /// "Spatial audio" widens the stereo field. Klack's actual spatialisation is
    /// not published; this is an interpretation, not a measurement.
    var spatialAudio = true
    /// "Ignore rapid key events": drop a down within 25 ms of the previous one.
    var ignoreRapidKeys = false
    private var lastDown = Date.distantPast
    /// Tone Pad. x is read as a pitch-centre offset, y as a level trim.
    var toneOffset: Float = 0
    var toneTrim: Float = 0
    /// Scales the ding and the mouse click, not the keystrokes.
    var effectsVolume: Float = 1.0
    private(set) var outputDeviceLabel = AudioDevices.systemDefaultLabel
    static var debugGain = false
    /// --sound-test --deterministic: always take variant 0.
    var deterministic = false

    private let engine = AVAudioEngine()
    private let mixer = Mixer()
    private var source: AVAudioSourceNode!
    private let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!

    private var down: [AVAudioPCMBuffer] = []
    private var up: [AVAudioPCMBuffer] = []
    private var ding: AVAudioPCMBuffer?
    /// Index into the mixer's flat pool: downs first, then ups, then the ding.
    private var downBase = 0, upBase = 0, dingIndex = -1
    private(set) var isRunning = false
    private(set) var loadedName = ""

    private init() {}

    /// Route to a named device. The output unit only accepts a device change
    /// while the engine is stopped, so this cycles it.
    func setOutput(_ label: String) {
        outputDeviceLabel = label
        guard isRunning, !engine.isInManualRenderingMode else { return }
        guard let id = AudioDevices.resolve(label) else { return }
        if AudioDevices.currentDevice(of: engine) == id { return }
        engine.stop()
        let ok = AudioDevices.setDevice(id, on: engine)
        do { try engine.start() }
        catch { FileHandle.standardError.write("restart after route: \(error)\n".data(using: .utf8)!) }
        if !ok { FileHandle.standardError.write("could not route to \(label)\n".data(using: .utf8)!) }
    }

    var currentOutputName: String {
        guard let id = AudioDevices.currentDevice(of: engine) else { return "unknown" }
        return AudioDevices.name(id) ?? "device \(id)"
    }

    // MARK: - lifecycle

    func start(manualRender: Bool = false) {
        guard !isRunning else { return }
        if manualRender {
            do { try engine.enableManualRenderingMode(.offline, format: format,
                                                      maximumFrameCount: 4096) }
            catch { FileHandle.standardError.write("manual render: \(error)\n".data(using: .utf8)!) }
        }
        let m = mixer
        source = AVAudioSourceNode(format: format) { _, _, frameCount, abl -> OSStatus in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            guard bufs.count >= 2,
                  let l = bufs[0].mData?.assumingMemoryBound(to: Float.self),
                  let r = bufs[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            m.render(frames: Int(frameCount), left: l, right: r)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
        load()
        do {
            engine.prepare()
            try engine.start()
            isRunning = true
        } catch {
            FileHandle.standardError.write("audio engine failed: \(error)\n".data(using: .utf8)!)
        }
    }

    func stop() {
        engine.stop()
        isRunning = false
    }

    /// Where the sliced samples live: inside the bundle when installed, or in
    /// the working tree when run from the build directory.
    private static func sampleRoot() -> URL? {
        if let u = Bundle.main.resourceURL?.appendingPathComponent("switches"),
           FileManager.default.fileExists(atPath: u.path) { return u }
        // Running straight out of the build directory: walk up from the
        // executable looking for the working tree's copy.
        var d = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        for _ in 0..<8 {
            d.deleteLastPathComponent()
            let c = d.appendingPathComponent("assets/switches")
            if FileManager.default.fileExists(atPath: c.path) { return c }
        }
        return nil
    }

    private func load() {
        let name = Catalog.groups.flatMap { $0.items }[
            min(switchIndex, Catalog.groups.flatMap { $0.items }.count - 1)].name
        loadedName = name
        down = []; up = []
        guard let root = SoundEngine.sampleRoot() else {
            FileHandle.standardError.write("no switch samples found\n".data(using: .utf8)!)
            return
        }
        let dir = root.appendingPathComponent(name.replacingOccurrences(of: " ", with: "_"))
        func loadAll(_ prefix: String) -> [AVAudioPCMBuffer] {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
            else { return [] }
            return files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".wav") }.sorted()
                .compactMap { f -> AVAudioPCMBuffer? in
                    guard let file = try? AVAudioFile(forReading: dir.appendingPathComponent(f)),
                          let mono = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                      frameCapacity: AVAudioFrameCount(file.length)),
                          (try? file.read(into: mono)) != nil else { return nil }
                    return toStereo(mono)
                }
        }
        down = loadAll("down_"); up = loadAll("up_")
        ding = Synth.ding(format: format)
        downBase = 0; upBase = down.count; dingIndex = down.count + up.count
        mixer.load(down + up + (ding.map { [$0] } ?? []))
    }

    /// The slices are mono 48 kHz; the graph runs stereo so panning works.
    private func toStereo(_ src: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: src.frameLength),
              let s = src.floatChannelData?[0] else { return nil }
        out.frameLength = src.frameLength
        let l = out.floatChannelData![0], r = out.floatChannelData![1]
        for i in 0..<Int(src.frameLength) { l[i] = s[i]; r[i] = s[i] }
        return out
    }

    // MARK: - triggering

    func play(down isDown: Bool, pan: Float, isModifier: Bool, isReturn: Bool) {
        guard enabled, !suppressed, isRunning else { return }
        if muteModifiers && isModifier { return }
        if isReturn && isDown && dingOnReturn, dingIndex >= 0 {
            fire(dingIndex, pan: 0, rate: 1, gain: 0.7 * effectsVolume)
            UsageStore.shared.countDing()
        }
        if isDown && ignoreRapidKeys {
            let now = Date()
            if now.timeIntervalSince(lastDown) < 0.025 { return }
            lastDown = now
        }
        let n = isDown ? down.count : up.count
        guard n > 0 else { return }
        let k = deterministic ? 0 : Int.random(in: 0..<n)
        let idx = (isDown ? downBase : upBase) + k
        var rate: Float = pitchVariation ? Float.random(in: 0.93...1.07) : 1.0
        rate *= 1 + toneOffset * 0.16
        let width: Float = spatialAudio ? 1.55 : 1.0
        let gain = (isDown ? 1.0 : Float(0.5)) * (1 + toneTrim * 0.35)
        fire(idx, pan: stereoPanning ? max(-1, min(1, pan * width)) : 0, rate: rate, gain: gain)
    }

    /// "Play mouse click sounds": reuses the current switch's up-stroke.
    var mouseClickSounds = false
    func playClick() {
        guard enabled, !suppressed, isRunning, mouseClickSounds, up.count > 0 else { return }
        fire(upBase + Int.random(in: 0..<up.count), pan: 0, rate: 0.9,
             gain: 0.45 * effectsVolume)
    }

    private func fire(_ index: Int, pan: Float, rate: Float, gain: Float) {
        let g = volume * gain
        // equal-power pan
        let a = (pan + 1) * 0.25 * Float.pi
        mixer.trigger(index, rate: rate, gainL: g * cos(a), gainR: g * sin(a))
        if SoundEngine.debugGain {
            print(String(format: "  fire: idx=%d master=%.3f gain=%.3f rate=%.3f",
                         index, volume, gain, rate))
        }
    }

    /// Offline render, used by --sound-test to make the output measurable.
    func renderOffline(seconds: Double, to url: URL, strokes: [(Double, Bool, Float)]) throws {
        let out = try AVAudioFile(forWriting: url,
                                  settings: format.settings,
                                  commonFormat: .pcmFormatFloat32, interleaved: false)
        let block = AVAudioFrameCount(1024)
        let buf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat,
                                   frameCapacity: block)!
        var t = 0.0
        var pending = strokes
        while t < seconds {
            while let s = pending.first, s.0 <= t {
                play(down: s.1, pan: s.2, isModifier: false, isReturn: dingOnReturn)
                pending.removeFirst()
            }
            let status = try engine.renderOffline(block, to: buf)
            if status == .success { try out.write(from: buf) }
            t += Double(block) / format.sampleRate
        }
    }
}

/// Only the return-key "ding" is synthesised — a short two-partial bell. There
/// is no CC0 recording of Klack's ding, and it is a UI sound rather than a
/// switch, so generating it is cleaner than sourcing a stand-in.
enum Synth {
    static func ding(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sr = Float(format.sampleRate)
        let n = Int(sr * 0.35)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buf.frameLength = AVAudioFrameCount(n)
        let L = buf.floatChannelData![0], R = buf.floatChannelData![1]
        for i in 0..<n {
            let t = Float(i) / sr
            let env = expf(-t / 0.09)
            var s = (sinf(2 * .pi * 1318.5 * t) * 0.6 + sinf(2 * .pi * 1975.5 * t) * 0.4) * env * 0.35
            if t < 0.002 { s *= t / 0.002 }
            L[i] = s; R[i] = s
        }
        return buf
    }

    /// Catmull-Rom rather than linear. Linear interpolation is a crude low-pass:
    /// it audibly dulls the very transient that gives a keystroke its snap, and
    /// pitch variation puts every press through it.
    static func resample(_ src: AVAudioPCMBuffer, rate: Float,
                         format: AVAudioFormat) -> AVAudioPCMBuffer {
        let n = max(16, Int(Float(src.frameLength) / rate))
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        out.frameLength = AVAudioFrameCount(n)
        let sL = src.floatChannelData![0]
        let dL = out.floatChannelData![0], dR = out.floatChannelData![1]
        let last = Int(src.frameLength) - 1
        @inline(__always) func tap(_ i: Int) -> Float { sL[max(0, min(i, last))] }
        for i in 0..<n {
            let p = Float(i) * rate
            let i1 = min(Int(p), last)
            let f = p - Float(i1)
            let p0 = tap(i1 - 1), p1 = tap(i1), p2 = tap(i1 + 1), p3 = tap(i1 + 2)
            let a = -0.5*p0 + 1.5*p1 - 1.5*p2 + 0.5*p3
            let b =      p0 - 2.5*p1 + 2.0*p2 - 0.5*p3
            let c = -0.5*p0          + 0.5*p2
            let s = ((a*f + b)*f + c)*f + p1
            dL[i] = s; dR[i] = s
        }
        return out
    }
}
