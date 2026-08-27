import CoreAudio
import AVFoundation

/// Output-device enumeration and routing, behind "Play sound through".
///
/// The reference shows the row with "System output" in the video and with the
/// machine's own name ("MacBook Air") in the light-mode capture, so the control
/// is a device picker whose first entry follows the system default.
enum AudioDevices {

    struct Device: Equatable { let id: AudioDeviceID; let name: String }

    static let systemDefaultLabel = "System output"

    private static func addr(_ selector: AudioObjectPropertySelector,
                             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal)
    -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    /// Every device that actually has output channels.
    static func outputs() -> [Device] {
        var a = addr(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                             &a, 0, nil, &size) == noErr else { return [] }
        let n = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: n)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard hasOutput(id), !isPrivate(id), let n = name(id) else { return nil }
            return Device(id: id, name: n)
        }
    }

    /// CoreAudio creates a private aggregate per client — its name carries the
    /// pid and changes every launch, so a stored selection could never match it
    /// again. Hidden devices and those aggregates are not offered.
    static func isPrivate(_ id: AudioDeviceID) -> Bool {
        var a = addr(kAudioDevicePropertyIsHidden)
        var hidden: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(id, &a, 0, nil, &size, &hidden) == noErr, hidden != 0 {
            return true
        }
        return (name(id) ?? "").hasPrefix("CADefaultDeviceAggregate")
    }

    static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var a = addr(kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size > 0 else { return false }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(size),
                                                   alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { buf.deallocate() }
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, buf) == noErr else { return false }
        let list = UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    static func name(_ id: AudioDeviceID) -> String? {
        var a = addr(kAudioObjectPropertyName)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cf: CFString? = nil
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &cf) == noErr, let cf else { return nil }
        return cf as String
    }

    static func systemDefault() -> AudioDeviceID? {
        var a = addr(kAudioHardwarePropertyDefaultOutputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                         &a, 0, nil, &size, &id) == noErr else { return nil }
        return id
    }

    /// Resolve a stored label to a device. Unknown names fall back to the system
    /// default rather than going silent — a device can be unplugged between runs.
    static func resolve(_ label: String) -> AudioDeviceID? {
        if label == systemDefaultLabel { return systemDefault() }
        if let d = outputs().first(where: { $0.name == label }) { return d.id }
        return systemDefault()
    }

    /// Read back which device an engine's output unit is currently on, which is
    /// the only way to confirm the routing actually took.
    static func currentDevice(of engine: AVAudioEngine) -> AudioDeviceID? {
        guard let au = engine.outputNode.audioUnit else { return nil }
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let err = AudioUnitGetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                                       kAudioUnitScope_Global, 0, &id, &size)
        return err == noErr ? id : nil
    }

    @discardableResult
    static func setDevice(_ id: AudioDeviceID, on engine: AVAudioEngine) -> Bool {
        guard let au = engine.outputNode.audioUnit else { return false }
        var d = id
        return AudioUnitSetProperty(au, kAudioOutputUnitProperty_CurrentDevice,
                                    kAudioUnitScope_Global, 0, &d,
                                    UInt32(MemoryLayout<AudioDeviceID>.size)) == noErr
    }
}
