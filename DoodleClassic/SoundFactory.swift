import AVFoundation
import Foundation

/// Every sound effect is synthesized here at launch — short PCM buffers
/// wrapped in WAV containers and handed to AVAudioPlayer. One-shots play
/// from small round-robin pools so overlapping bounces don't cut each
/// other off; the flight/hazard drones are seamless loops.
final class SoundFactory {

    static let shared = SoundFactory()

    enum Effect: CaseIterable {
        case bounce, spring, trampoline, shoot, stomp, crumble, whitePoof
        case fall, blackHole, pickup, button, fuse, boom
    }

    enum Loop: CaseIterable {
        case propeller, rocket, monster, ufo
    }

    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "soundEnabled") }
    }

    private var pools: [Effect: [AVAudioPlayer]] = [:]
    private var poolIndex: [Effect: Int] = [:]
    private var loops: [Loop: AVAudioPlayer] = [:]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for effect in Effect.allCases {
            let data = Self.wavData(samples: Self.render(effect))
            let players = (0..<3).compactMap { _ -> AVAudioPlayer? in
                guard let p = try? AVAudioPlayer(data: data) else { return nil }
                p.prepareToPlay()
                return p
            }
            pools[effect] = players
            poolIndex[effect] = 0
        }
        for loop in Loop.allCases {
            let data = Self.wavData(samples: Self.render(loop))
            if let p = try? AVAudioPlayer(data: data) {
                p.numberOfLoops = -1
                p.volume = Self.loopVolume(loop)
                p.prepareToPlay()
                loops[loop] = p
            }
        }
    }

    func play(_ effect: Effect) {
        guard enabled, let pool = pools[effect], !pool.isEmpty else { return }
        let i = (poolIndex[effect] ?? 0) % pool.count
        poolIndex[effect] = i + 1
        let player = pool[i]
        player.currentTime = 0
        player.play()
    }

    func start(_ loop: Loop) {
        guard enabled, let p = loops[loop], !p.isPlaying else { return }
        p.currentTime = 0
        p.play()
    }

    func stop(_ loop: Loop) {
        loops[loop]?.stop()
    }

    func stopAllLoops() {
        for p in loops.values { p.stop() }
    }

    // MARK: - synthesis

    private static let rate: Double = 44_100

    private static func loopVolume(_ loop: Loop) -> Float {
        switch loop {
        case .propeller: return 0.45
        case .rocket: return 0.5
        case .monster: return 0.30
        case .ufo: return 0.35
        }
    }

    /// Deterministic noise so the sounds are identical every launch.
    private struct NoiseSource {
        var state: UInt64 = 0x9E3779B97F4A7C15
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF) * 2 - 1
        }
    }

    private static func envelope(_ t: Double, attack: Double, total: Double,
                                 release: Double) -> Double {
        if t < attack { return t / attack }
        let tail = total - release
        if t > tail { return max(0, (total - t) / release) }
        return 1
    }

    private static func render(_ effect: Effect) -> [Float] {
        switch effect {
        case .bounce:
            // soft rubbery "boing": quick upward chirp, fast decay
            return tone(duration: 0.13) { t, d in
                let f = 380 + 420 * (t / d)
                let amp = envelope(t, attack: 0.004, total: d, release: 0.06) * exp(-t * 18)
                return (sin(2 * .pi * f * t) + 0.35 * sin(4 * .pi * f * t)) * amp * 0.55
            }
        case .spring:
            // springier, longer, with a twangy vibrato
            return tone(duration: 0.32) { t, d in
                let f = 450 + 950 * (t / d) + 60 * sin(2 * .pi * 26 * t)
                let amp = envelope(t, attack: 0.004, total: d, release: 0.12) * exp(-t * 7)
                return (sin(2 * .pi * f * t) + 0.3 * sin(4 * .pi * f * t)) * amp * 0.6
            }
        case .trampoline:
            // deep bounce then a high flick
            return tone(duration: 0.4) { t, d in
                let low = sin(2 * .pi * (180 + 240 * t / d) * t) * exp(-t * 9)
                let hi = t > 0.12 ? sin(2 * .pi * (900 + 800 * (t - 0.12)) * t) * exp(-(t - 0.12) * 14) : 0
                return (low * 0.6 + hi * 0.4) * envelope(t, attack: 0.004, total: d, release: 0.1)
            }
        case .shoot:
            // little "pew" pop
            return tone(duration: 0.07) { t, d in
                let f = 1000.0 + 900 * (t / d)
                return sin(2 * .pi * f * t) * envelope(t, attack: 0.002, total: d, release: 0.03) * exp(-t * 30) * 0.5
            }
        case .stomp:
            // squashy splat: noise burst over a falling thud
            var noise = NoiseSource()
            return tone(duration: 0.22) { t, d in
                let thud = sin(2 * .pi * (220 - 160 * t / d) * t) * 0.6
                let splat = noise.next() * exp(-t * 26) * 0.5
                return (thud + splat) * envelope(t, attack: 0.003, total: d, release: 0.08) * exp(-t * 10)
            }
        case .crumble:
            // three dry cracks
            var noise = NoiseSource()
            return tone(duration: 0.28) { t, _ in
                let bursts = [0.0, 0.09, 0.17]
                var v = 0.0
                for b in bursts where t >= b && t < b + 0.05 {
                    v += noise.next() * exp(-(t - b) * 70)
                }
                return v * 0.5
            }
        case .whitePoof:
            var noise = NoiseSource()
            return tone(duration: 0.06) { t, d in
                noise.next() * envelope(t, attack: 0.002, total: d, release: 0.03) * exp(-t * 60) * 0.3
            }
        case .fall:
            // long descending slide-whistle
            return tone(duration: 0.95) { t, d in
                let f = 1050 - 880 * (t / d) + 30 * sin(2 * .pi * 7 * t)
                return sin(2 * .pi * f * t) * envelope(t, attack: 0.01, total: d, release: 0.25) * 0.5
            }
        case .blackHole:
            // swallowed: noise + tone spiralling down
            var noise = NoiseSource()
            return tone(duration: 0.7) { t, d in
                let f = 500 - 420 * (t / d)
                let swirl = sin(2 * .pi * f * t + 4 * sin(2 * .pi * 3 * t))
                return (swirl * 0.5 + noise.next() * 0.15 * (1 - t / d)) *
                    envelope(t, attack: 0.02, total: d, release: 0.2)
            }
        case .pickup:
            // bright double blip; each segment gets its own half-sine
            // window so the frequency switch can't click
            return tone(duration: 0.16) { t, _ in
                if t < 0.065 {
                    return sin(2 * .pi * 880 * t) * sin(.pi * t / 0.065) * 0.45
                }
                if t >= 0.07 {
                    let u = t - 0.07
                    return sin(2 * .pi * 1320 * u) * sin(.pi * min(1, u / 0.09)) * 0.45
                }
                return 0
            }
        case .button:
            return tone(duration: 0.05) { t, d in
                sin(2 * .pi * 700 * t) * envelope(t, attack: 0.002, total: d, release: 0.02) * 0.4
            }
        case .fuse:
            // crackling sizzle while the exploding platform arms
            var noise = NoiseSource()
            return tone(duration: 0.5) { t, d in
                let crackle = noise.next() * (0.5 + 0.5 * sin(2 * .pi * 30 * t))
                return crackle * envelope(t, attack: 0.02, total: d, release: 0.1) * 0.22
            }
        case .boom:
            // low thump with a noise bloom
            var noise = NoiseSource()
            var smoothed = 0.0
            return tone(duration: 0.5) { t, d in
                smoothed += (noise.next() - smoothed) * 0.3
                let thump = sin(2 * .pi * (110 - 70 * t / d) * t)
                return (thump * 0.7 + smoothed * 0.6) *
                    envelope(t, attack: 0.004, total: d, release: 0.2) * exp(-t * 6)
            }
        }
    }

    private static func render(_ loop: Loop) -> [Float] {
        switch loop {
        case .propeller:
            // beanie flutter: buzzy low tone chopped at blade rate.
            // Modulators complete whole cycles over the loop for a seamless join.
            return tone(duration: 0.4) { t, _ in
                let chop = 0.55 + 0.45 * sin(2 * .pi * 25 * t)
                let buzz = sin(2 * .pi * 95 * t) + 0.4 * sin(2 * .pi * 190 * t)
                return buzz * chop * 0.5
            }
        case .rocket:
            // filtered roar: noise smoothed into a rumble with slow surge
            var noise = NoiseSource()
            var smoothed = 0.0
            return tone(duration: 0.5) { t, _ in
                smoothed += (noise.next() - smoothed) * 0.18
                let surge = 0.8 + 0.2 * sin(2 * .pi * 4 * t)
                return smoothed * surge * 1.4
            }
        case .monster:
            // uneasy warble
            return tone(duration: 0.8) { t, _ in
                let f = 210 + 34 * sin(2 * .pi * 5 * t)
                return (sin(2 * .pi * f * t) + 0.3 * sin(2 * .pi * f * 2 * t)) * 0.4
            }
        case .ufo:
            // theremin wail
            return tone(duration: 0.75) { t, _ in
                let f = 620 + 90 * sin(2 * .pi * 4 * t)
                return sin(2 * .pi * f * t) * 0.45
            }
        }
    }

    private static func tone(duration: Double,
                             sample: (Double, Double) -> Double) -> [Float] {
        let count = Int(duration * rate)
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / rate
            out[i] = Float(max(-1, min(1, sample(t, duration))))
        }
        return out
    }

    private static func wavData(samples: [Float]) -> Data {
        var data = Data()
        let byteRate = UInt32(rate) * 2
        let dataSize = UInt32(samples.count * 2)
        func append<T>(_ value: T) {
            var v = value
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))              // PCM
        append(UInt16(1))              // mono
        append(UInt32(rate))
        append(byteRate)
        append(UInt16(2))              // block align
        append(UInt16(16))             // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        for s in samples {
            append(Int16(max(-32767, min(32767, s * 32767))))
        }
        return data
    }
}
