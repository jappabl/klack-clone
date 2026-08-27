import AppKit
import AVFoundation
import CoreAudio
import IOKit
import IOKit.hid
import EventKit

/// The Sleep pane's triggers, actually reading the system.
///
/// The trigger list, its order and which one is checked are sourced from the
/// review video. How Klack detects each condition is not published, so each
/// detector below is my own — and where a condition cannot be read with public
/// API and no prompt, it reports `.unavailable` rather than pretending.
final class SleepTriggers {

    static let shared = SleepTriggers()

    enum Reading { case active, inactive, unavailable(String) }

    /// Which triggers the user has enabled, keyed by label. Only the enabled
    /// ones are polled and only they can silence the app.
    var enabled: Set<String> = ["Focus"]      // matches the reference's state

    private(set) var readings: [String: Reading] = [:]
    private var timer: Timer?
    private var eventStore: EKEventStore?
    private(set) var isAsleep = false
    var onChange: (() -> Void)?

    private init() {}

    func start(interval: TimeInterval = 2.0) {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func poll() {
        var r: [String: Reading] = [:]
        for t in SleepPane.triggers {
            r[t.label] = enabled.contains(t.label) ? read(t.label) : .inactive
        }
        readings = r
        let sleeping = r.contains { k, v in
            if case .active = v { return enabled.contains(k) }
            return false
        }
        if sleeping != isAsleep {
            isAsleep = sleeping
            SoundEngine.shared.suppressed = sleeping
            onChange?()
        }
    }

    func read(_ label: String) -> Reading {
        switch label {
        case "Bluetooth":         return SleepTriggers.bluetoothOn()
        case "External Keyboard": return SleepTriggers.externalKeyboard()
        case "Headphones":        return SleepTriggers.outputIs(headphones: true)
        case "Speakers":          return SleepTriggers.outputIs(headphones: false)
        case "Camera":            return SleepTriggers.captureInUse(.video)
        case "Microphone":        return SleepTriggers.captureInUse(.audio)
        case "Screen Sharing":    return SleepTriggers.screenSharing()
        case "Focus":             return SleepTriggers.focusOn()
        case "Calendar Event":    return calendarBusy()
        case "Now Playing":
            // Reading "is something playing" needs the private MediaRemote
            // framework. Not worth shipping a private dependency for one row.
            return .unavailable("needs private MediaRemote API")
        default: return .unavailable("no detector")
        }
    }

    // MARK: - detectors

    /// Two dead ends before this one: `IOBluetoothHostController` blocks on a
    /// CoreBluetooth coordinator that needs a running run loop (deadlock, then
    /// SIGABRT), and `com.apple.Bluetooth.plist` no longer carries
    /// `ControllerPowerState` on macOS 26. system_profiler does report it, so
    /// that is what this uses — cached, because it costs ~1 s and the poll runs
    /// every 2.
    private static var btCache: (Date, Reading)?
    static func bluetoothOn() -> Reading {
        if let c = btCache, Date().timeIntervalSince(c.0) < 30 { return c.1 }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        var r = Reading.unavailable("system_profiler failed")
        if (try? p.run()) != nil {
            let d = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            if let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
               let arr = j["SPBluetoothDataType"] as? [[String: Any]], let first = arr.first,
               let props = first["controller_properties"] as? [String: Any],
               let state = props["controller_state"] as? String {
                r = state.contains("on") ? .active : .inactive
            }
        }
        btCache = (Date(), r)
        return r
    }

    /// Any keyboard-shaped HID device that is not Apple's built-in one.
    static func externalKeyboard() -> Reading {
        guard let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
                as IOHIDManager? else { return .unavailable("HID manager") }
        let match: [String: Any] = [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                                    kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard]
        IOHIDManagerSetDeviceMatching(mgr, match as CFDictionary)
        IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone)) }
        guard let set = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else { return .inactive }
        for d in set {
            let transport = IOHIDDeviceGetProperty(d, kIOHIDTransportKey as CFString) as? String ?? ""
            // the built-in keyboard reports SPI/FIFO; anything on USB or
            // Bluetooth is external
            if transport.caseInsensitiveCompare("USB") == .orderedSame
                || transport.localizedCaseInsensitiveContains("bluetooth") {
                return .active
            }
        }
        return .inactive
    }

    /// Transport type of the current default output device.
    static func outputIs(headphones: Bool) -> Reading {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &addr, 0, nil, &size, &id) == noErr else {
            return .unavailable("no default output")
        }
        var transport = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        addr.mSelector = kAudioDevicePropertyTransportType
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport) == noErr else {
            return .unavailable("no transport type")
        }
        // Built-in output can still be driving headphones through the jack, so
        // ask the data source too.
        var source = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        addr.mSelector = kAudioDevicePropertyDataSource
        addr.mScope = kAudioDevicePropertyScopeOutput
        let haveSource = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &source) == noErr
        let hp = fourCC("hdpn")           // headphone data source
        let isBuiltIn = transport == kAudioDeviceTransportTypeBuiltIn
        let viaJack = haveSource && source == hp
        let wireless = transport == kAudioDeviceTransportTypeBluetooth
                    || transport == kAudioDeviceTransportTypeUSB
        let usingHeadphones = viaJack || (!isBuiltIn && wireless)
        return (usingHeadphones == headphones) ? .active : .inactive
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    /// Is any app currently capturing from the camera / microphone?
    static func captureInUse(_ media: AVMediaType) -> Reading {
        let types: [AVCaptureDevice.DeviceType] = media == .video
            ? [.builtInWideAngleCamera, .external]
            : [.microphone, .external]
        let s = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: media, position: .unspecified)
        if s.devices.isEmpty { return .inactive }
        return s.devices.contains { $0.isInUseByAnotherApplication } ? .active : .inactive
    }

    static func screenSharing() -> Reading {
        let names = ["screensharingd", "ScreensharingAgent", "AppleVNCServer"]
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/ps")
        p.arguments = ["-Ao", "comm"]
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
        do { try p.run() } catch { return .unavailable("ps failed") }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return names.contains(where: { out.contains($0) }) ? .active : .inactive
    }

    /// Focus has no public read API. Older macOS kept active modes in
    /// `~/Library/DoNotDisturb/DB/Assertions.json`; on macOS 26 that directory
    /// does not exist, and `com.apple.donotdisturbd.plist` holds only CloudKit
    /// cache keys. Reporting that beats guessing — and it is worth flagging,
    /// because Focus is the one trigger the reference shows switched on.
    static func focusOn() -> Reading {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let legacy = home.appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        if let d = try? Data(contentsOf: legacy),
           let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
           let recs = j["data"] as? [[String: Any]] {
            for r in recs {
                if let a = r["storeAssertionRecords"] as? [[String: Any]], !a.isEmpty { return .active }
            }
            return .inactive
        }
        return .unavailable("no public API on macOS 26")
    }

    /// EventKit, and only when the user has enabled this trigger — access is
    /// requested at that point rather than at launch.
    private func calendarBusy() -> Reading {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            let store = eventStore ?? { let s = EKEventStore(); eventStore = s; return s }()
            let now = Date()
            let p = store.predicateForEvents(withStart: now.addingTimeInterval(-60),
                                             end: now.addingTimeInterval(60), calendars: nil)
            let busy = store.events(matching: p).contains { !$0.isAllDay && $0.startDate <= now && $0.endDate >= now }
            return busy ? .active : .inactive
        case .notDetermined: return .unavailable("Calendar access not granted")
        default:             return .unavailable("Calendar access denied")
        }
    }

    func requestCalendarAccess(_ done: @escaping (Bool) -> Void) {
        let s = eventStore ?? { let x = EKEventStore(); eventStore = x; return x }()
        s.requestFullAccessToEvents { ok, _ in DispatchQueue.main.async { done(ok) } }
    }
}
