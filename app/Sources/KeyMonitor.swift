import AppKit
import Carbon.HIToolbox

/// Turns keystrokes into sound triggers.
///
/// Two paths, on purpose:
///  - **local** — `NSEvent.addLocalMonitorForEvents` fires while one of the
///    app's own windows is focused. Needs no permission, so the sound can be
///    tried immediately.
///  - **global** — a `CGEventTap` hears the whole system, which is what Klack
///    actually does. That needs Accessibility, which is never requested
///    silently: `AXIsProcessTrusted()` is checked and the caller is told.
final class KeyMonitor {

    static let shared = KeyMonitor()
    private var local: Any?
    private var tap: CFMachPort?
    private(set) var globalActive = false

    private init() {}

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    func startLocal() {
        guard local == nil else { return }
        local = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown]
        ) { [weak self] e in
            self?.handle(e); return e
        }
    }

    /// Returns false when Accessibility has not been granted; nothing is
    /// prompted for.
    @discardableResult
    func startGlobal() -> Bool {
        guard tap == nil else { return globalActive }
        guard hasAccessibility else { return false }
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)
                 | (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.rightMouseDown.rawValue)
        let cb: CGEventTapCallBack = { _, type, event, _ in
            if type == .leftMouseDown || type == .rightMouseDown {
                UsageStore.shared.countClick()
                SoundEngine.shared.playClick()
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
                                        callback: cb, userInfo: nil) else { return false }
        tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        globalActive = true
        return true
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .keyDown where !e.isARepeat: trigger(keyCode: e.keyCode, down: true)
        case .keyUp:                      trigger(keyCode: e.keyCode, down: false)
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

    // MARK: - key geometry

    static let modifiers: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    /// Column of each key on a US ANSI layout, 0 (left) to 13 (right). Spatial
    /// audio in the real app places a keystroke where the key physically is;
    /// this is the same idea with a hand-built map, since macOS virtual key
    /// codes carry no positional information.
    private static let column: [UInt16: Float] = {
        var m: [UInt16: Float] = [:]
        let rows: [[UInt16]] = [
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
