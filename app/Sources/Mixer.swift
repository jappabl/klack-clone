import AVFoundation
import Synchronization

/// A tiny voice mixer with a real brickwall limiter, rendered by one
/// `AVAudioSourceNode`.
///
/// The player-node-per-voice design it replaces was fine for latency but had no
/// way to see the *sum*, and neither Apple effect would hold it: AUPeakLimiter
/// measured peaks going **up** (Cream 0.866 → 1.044) and AUDynamicsProcessor at
/// −6 dBFS still let a burst reach 1.53. Meanwhile ordinary fast typing already
/// peaked at 0.99, so there was nothing left to give away as headroom.
///
/// Owning the mix fixes that: the limiter sees every sample of the sum, and the
/// per-voice resampling is the same Catmull-Rom used elsewhere rather than an
/// AU's own conversion.
final class Mixer: @unchecked Sendable {

    struct Trigger {
        var bufferIndex: Int32 = -1
        var rate: Float = 1
        var gainL: Float = 0
        var gainR: Float = 0
    }

    private struct Voice {
        var buffer: Int32 = -1
        var pos: Double = 0
        var rate: Double = 1
        var gL: Float = 0
        var gR: Float = 0
    }

    /// Sample data, held for the lifetime of the load; the audio thread only
    /// ever reads through these pointers.
    private var pools: [[UnsafeMutablePointer<Float>]] = []
    private var lengths: [[Int]] = []
    private var flatData: [UnsafeMutablePointer<Float>] = []
    private var flatLen: [Int] = []

    private var voices = [Voice](repeating: Voice(), count: 32)
    private var nextVoice = 0

    // single-producer / single-consumer ring: the UI thread writes, the audio
    // thread reads. No locks on the render path.
    private let ringSize = 256
    private var ring: UnsafeMutablePointer<Trigger>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(0)

    /// Brickwall state.
    private var env: Float = 0
    var ceiling: Float = 0.95
    private let release: Float = 0.9995      // ~50 ms at 48 kHz

    init() {
        ring = UnsafeMutablePointer<Trigger>.allocate(capacity: ringSize)
        ring.initialize(repeating: Trigger(), count: ringSize)
    }

    deinit {
        ring.deallocate()
        flatData.forEach { $0.deallocate() }
    }

    /// Replace the sample set. Called on the main thread while the engine is
    /// running; old storage is kept until the next load so a voice mid-flight
    /// never reads freed memory.
    private var retired: [UnsafeMutablePointer<Float>] = []
    func load(_ buffers: [AVAudioPCMBuffer]) {
        retired.forEach { $0.deallocate() }
        retired = flatData
        flatData = []; flatLen = []
        for b in buffers {
            let n = Int(b.frameLength)
            let p = UnsafeMutablePointer<Float>.allocate(capacity: max(n, 1))
            if let src = b.floatChannelData?[0] { p.update(from: src, count: n) }
            flatData.append(p); flatLen.append(n)
        }
        for i in voices.indices { voices[i].buffer = -1 }
    }

    var count: Int { flatData.count }

    /// Queue a voice. Safe to call from any non-audio thread.
    func trigger(_ index: Int, rate: Float, gainL: Float, gainR: Float) {
        guard index >= 0, index < flatData.count else { return }
        let w = writeIndex.load(ordering: .relaxed)
        let r = readIndex.load(ordering: .acquiring)
        if w - r >= ringSize { return }                 // overflow: drop, never block
        ring[w % ringSize] = Trigger(bufferIndex: Int32(index), rate: rate,
                                     gainL: gainL, gainR: gainR)
        writeIndex.store(w + 1, ordering: .releasing)
    }

    /// The render callback. No allocation, no locks.
    func render(frames: Int, left: UnsafeMutablePointer<Float>,
                right: UnsafeMutablePointer<Float>) {
        // drain queued triggers into free voices
        var r = readIndex.load(ordering: .relaxed)
        let w = writeIndex.load(ordering: .acquiring)
        while r < w {
            let t = ring[r % ringSize]
            var slot = -1
            for _ in 0..<voices.count {
                nextVoice = (nextVoice + 1) % voices.count
                if voices[nextVoice].buffer < 0 { slot = nextVoice; break }
            }
            if slot < 0 { slot = nextVoice }            // steal the oldest
            voices[slot] = Voice(buffer: t.bufferIndex, pos: 0,
                                 rate: Double(t.rate), gL: t.gainL, gR: t.gainR)
            r += 1
        }
        readIndex.store(r, ordering: .releasing)

        for i in 0..<frames {
            var l: Float = 0, rr: Float = 0
            for v in voices.indices {
                let b = Int(voices[v].buffer)
                if b < 0 { continue }
                let n = flatLen[b]
                let p = voices[v].pos
                let i1 = Int(p)
                if i1 >= n - 2 { voices[v].buffer = -1; continue }
                let d = flatData[b]
                let f = Float(p - Double(i1))
                let p0 = d[max(0, i1 - 1)], p1 = d[i1], p2 = d[i1 + 1], p3 = d[min(n - 1, i1 + 2)]
                let a = -0.5*p0 + 1.5*p1 - 1.5*p2 + 0.5*p3
                let bq =      p0 - 2.5*p1 + 2.0*p2 - 0.5*p3
                let c = -0.5*p0          + 0.5*p2
                let s = ((a*f + bq)*f + c)*f + p1
                l += s * voices[v].gL
                rr += s * voices[v].gR
                voices[v].pos = p + voices[v].rate
            }
            // brickwall: instantaneous attack, exponential release, so the sum
            // can never leave [-ceiling, ceiling]
            let peak = max(abs(l), abs(rr))
            if peak > env { env = peak } else { env *= release }
            let g: Float = env > ceiling ? ceiling / env : 1
            left[i] = l * g
            right[i] = rr * g
        }
    }
}
