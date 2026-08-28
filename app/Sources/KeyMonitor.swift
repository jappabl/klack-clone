import AppKit
import Carbon.HIToolbox

/// Turns keystrokes into sound triggers.
///
/// Two paths, on purpose:
///  - **local** — `NSEvent.addLocalMonitorForEvents` fires while one of the
///    app's own windows is focused. Needs no permission, so the sound can be
///    tried immediately.
///  - **global** — a `CGEventTap` hears the whole system, which is what Klack
///    actually does. That needs **Input Monitoring** — a listen-only keyboard
///    tap is gated by kTCCServiceListenEvent, not by Accessibility, though
///    Accessibility also permits one. Nothing is ever requested silently.
final class KeyMonitor {

    static let shared = KeyMonitor()
    private var local: Any?
    private var tap: CFMachPort?
    private(set) var globalActive = false

    private init() {}

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// A `.listenOnly` keyboard tap is gated by **Input Monitoring**
    /// (kTCCServiceListenEvent), which is a different grant from
    /// Accessibility. Checking only the latter reports success while the tap
    /// sits there receiving nothing.
    var hasInputMonitoring: Bool { CGPreflightListenEventAccess() }

    /// Whether the tap is not just created but actually live. macOS disables a
    /// tap whose grant went stale, and it does so silently.
    var tapEnabled: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func startLocal() {
        guard local == nil else { return }
        local = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown,
                       .systemDefined]
        ) { [weak self] e in
            self?.handle(e); return e
        }
    }

    /// Why the global tap is not running, or nil when it is.
    private(set) var blockedBy: String?

    /// Returns false when the tap could not be armed. Nothing is prompted for:
    /// both checks are preflights, and `tapCreate` is only reached once at
    /// least one grant is already in place.
    ///
    /// Input Monitoring is the grant that matters for a `.listenOnly`
    /// keyboard tap; Accessibility also permits one. Requiring both would
    /// refuse a machine that has the right one, so this needs *either* and
    /// then verifies the tap really came up.
    /// Events the global tap has actually seen. The preflight APIs report
    /// what TCC has on file; this reports what arrived.
    var globalEventCount = 0

    /// Counted separately from `globalEventCount`, because the top row is the
    /// thing being measured and ordinary typing swamps a combined total.
    var auxEventCount = 0

    /// Arm the system-wide tap.
    ///
    /// `tapCreate` is attempted unconditionally. The preflight APIs report
    /// what TCC has on file, and for an ad-hoc-signed bundle that is not a
    /// reliable predictor of whether a tap will be permitted — gating on them
    /// can refuse a machine where the tap would in fact have worked. So they
    /// are used only to explain a failure, never to cause one.
    ///
    /// The authority is: did a tap come back, and is it enabled.
    @discardableResult
    func startGlobal() -> Bool {
        guard tap == nil else { return globalActive }
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)
                 | (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.rightMouseDown.rawValue)
                 | (1 << KeyMonitor.systemDefined)
        let cb: CGEventTapCallBack = { _, type, event, _ in
            KeyMonitor.shared.globalEventCount += 1
            if type == .leftMouseDown || type == .rightMouseDown {
                UsageStore.shared.countClick()
                SoundEngine.shared.playClick()
                return Unmanaged.passUnretained(event)
            }
            // The top row of a Mac keyboard does not emit key events at all —
            // brightness, volume, playback and keyboard backlight arrive as
            // NX_SYSDEFINED instead, carrying their key in data1 rather than
            // in a keycode field. Without this the whole function row is silent.
            if type.rawValue == KeyMonitor.systemDefined {
                if let aux = KeyMonitor.auxKey(event) {
                    KeyMonitor.shared.auxEventCount += 1
                    KeyMonitor.shared.trigger(keyCode: aux.key, down: aux.down)
                }
                return Unmanaged.passUnretained(event)
            }
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let repeated = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if !repeated {
                KeyMonitor.shared.trigger(keyCode: code, down: type == .keyDown)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .listenOnly,
                                        eventsOfInterest: CGEventMask(mask),
                                        callback: cb, userInfo: nil) else {
            blockedBy = "macOS refused the tap — grant Input Monitoring to "
                      + Bundle.main.bundlePath
            return false
        }
        tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        // A tap can come back and still not be live, silently.
        guard CGEvent.tapIsEnabled(tap: t) else {
            blockedBy = "the tap was created but macOS left it disabled"
            return false
        }
        globalActive = true
        blockedBy = nil
        return true
    }

    /// Ask for both grants. Only ever called from an explicit user action —
    /// the `--grant` flag — never at launch.
    func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        _ = CGRequestListenEventAccess()
    }

    /// Open the two panes directly, since finding them by hand is the actual
    /// obstacle.
    static func openSettingsPanes() {
        for p in ["Privacy_ListenEvent", "Privacy_Accessibility"] {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?\(p)")!)
        }
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .keyDown where !e.isARepeat: trigger(keyCode: e.keyCode, down: true)
        case .keyUp:                      trigger(keyCode: e.keyCode, down: false)
        case .systemDefined:
            if let cg = e.cgEvent, let aux = KeyMonitor.auxKey(cg) {
                trigger(keyCode: aux.key, down: aux.down)
            }
        case .leftMouseDown, .rightMouseDown:
            UsageStore.shared.countClick()
            SoundEngine.shared.playClick()
        default: break
        }
    }

    func trigger(keyCode: UInt16, down: Bool) {
        if down && !KeyMonitor.modifiers.contains(keyCode) {
            UsageStore.shared.countKeystroke(switchName: SoundEngine.shared.loadedName)
        }
        SoundEngine.shared.play(down: down,
                                pan: KeyMonitor.pan(for: keyCode),
                                isModifier: KeyMonitor.modifiers.contains(keyCode),
                                isReturn: keyCode == 36)
    }

    /// `CGEventType` has no case for NX_SYSDEFINED.
    static let systemDefined = 14

    /// Decode an NX_SYSDEFINED event into the F-key sharing its physical spot.
    ///
    /// These carry everything packed into `data1`: the aux key in the high 16
    /// bits, and state in the low ones — 0x0A means down, 0x0B up. Returning an
    /// F-key rather than the aux code lets the existing column map place the
    /// sound without a second table of positions.
    static func auxKey(_ event: CGEvent) -> (key: UInt16, down: Bool)? {
        guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined,
              ns.subtype.rawValue == 8 else { return nil }
        let d1 = ns.data1
        let flags = d1 & 0xFFFF
        guard flags & 0x1 == 0 else { return nil }          // key repeat
        let state = (flags & 0xFF00) >> 8
        guard state == 0x0A || state == 0x0B else { return nil }
        guard let f = auxToFKey[(d1 & 0xFFFF_0000) >> 16] else { return nil }
        return (f, state == 0x0A)
    }

    /// NX_KEYTYPE_* to the F-key occupying the same place on the top row, so a
    /// volume key sounds from the right and a brightness key from the left.
    private static let auxToFKey: [Int: UInt16] = [
        3:  122,   // brightness down   F1
        2:  120,   // brightness up     F2
        22:  96,   // illumination down F5
        21:  97,   // illumination up   F6
        18:  98,   // previous          F7
        20:  98,   // rewind            F7
        16: 100,   // play/pause        F8
        17: 101,   // next              F9
        19: 101,   // fast-forward      F9
        7:  109,   // mute              F10
        1:  103,   // volume down       F11
        0:  111,   // volume up         F12
    ]

    // MARK: - key geometry

    static let modifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    /// Column of each key on a US ANSI layout, 0 (left) to 13 (right). Spatial
    /// audio in the real app places a keystroke where the key physically is;
    /// this is the same idea with a hand-built map, since macOS virtual key
    /// codes carry no positional information.
    private static let column: [UInt16: Float] = {
        var m: [UInt16: Float] = [:]
        let rows: [[UInt16]] = [
            [53, 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111], // esc F1..F12
            [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51],     // ` 1..0 - = ⌫
            [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],     // ⇥ q..p [ ] \
            [57,  0,  1,  2,  3,  5,  4, 38, 40, 37, 41, 39, 36],         // ⇪ a..; ' ⏎
            [56,  6,  7,  8,  9, 11, 45, 46, 43, 47, 44, 60],             // ⇧ z../ ⇧
            [59, 58, 55, 49, 54, 61, 62],                                  // ctrl opt cmd space
        ]
        for r in rows {
            let n = Float(max(r.count - 1, 1))
            for (i, k) in r.enumerated() where m[k] == nil {
                m[k] = Float(i) / n
            }
        }
        return m
    }()

    static func pan(for keyCode: UInt16) -> Float {
        let c = column[keyCode] ?? 0.5
        return (c * 2 - 1) * 0.55        // keep it well short of hard-panned
    }
}
