import AVFoundation
import Foundation

/// Every sound effect is synthesized here at launch — short PCM buffers
/// wrapped in WAV containers and handed to AVAudioPlayer. One-shots play
/// from small round-robin pools so overlapping bounces don't cut each
/// other off; the flight/hazard drones are seamless loops.
///
/// Swept tones use a **phase accumulator** (`phase += 2π·f·dt`). Writing
/// `sin(2π·f(t)·t)` instead looks equivalent but is not: the instantaneous
/// frequency of that expression is `f + t·f′`, which overshoots rising
/// sweeps and drives falling sweeps through zero into negative territory,
/// where they audibly reverse direction.
final class SoundFactory {

    static let shared = SoundFactory()

    enum Effect: CaseIterable {
        case bounce, spring, trampoline, shoot, stomp, crumble, whitePoof
        case shieldBreak, fall, blackHole, abduct, pickup, button, fuse, boom
    }

    enum Loop: CaseIterable {
        case propeller, jetpack, monster, ufo
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
                p.volume = Self.effectVolume(effect)
                p.prepareToPlay()
                return p
            }
            pools[effect] = players
            poolIndex[effect] = 0
        }
        for loop in Loop.allCases {
            var samples = Self.render(loop)
            if loop == .jetpack {
                // noise-based, so its tail will not line up with its head
                samples = Self.seamless(samples)
            }
            if let p = try? AVAudioPlayer(data: Self.wavData(samples: samples)) {
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

    // MARK: - mix levels

    /// The bounce plays constantly, so it sits below the event sounds; the
    /// hazard cues sit on top because they are warnings.
    private static func effectVolume(_ effect: Effect) -> Float {
        switch effect {
        case .bounce: return 0.55
        case .button, .whitePoof: return 0.6
        case .crumble, .shoot: return 0.75
        case .fall, .blackHole, .abduct, .boom, .shieldBreak: return 1.0
        default: return 0.85
        }
    }

    private static func loopVolume(_ loop: Loop) -> Float {
        switch loop {
        case .propeller: return 0.45
        case .jetpack: return 0.5
        case .monster: return 0.34
        case .ufo: return 0.38
        }
    }

    // MARK: - synthesis primitives

    private static let rate: Double = 44_100

    /// Deterministic noise so the sounds are identical every launch.
    private struct NoiseSource {
        var state: UInt64
        init(_ seed: UInt64) { state = seed | 1 }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF) * 2 - 1
        }
    }

    /// Click-free attack/release window.
    private static func envAD(_ t: Double, _ d: Double,
                              _ attack: Double, _ release: Double) -> Double {
        let a = attack > 0 ? min(1, t / attack) : 1
        let r = release > 0 ? min(1, (d - t) / release) : 1
        return max(0, a * r)
    }

    private static func tone(duration: Double,
                             sample: (Double, Double, Double) -> Double) -> [Float] {
        let count = Int(duration * rate)
        let dt = 1.0 / rate
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let v = sample(Double(i) * dt, duration, dt)
            out[i] = Float(max(-1, min(1, v)))
        }
        return out
    }

    /// Crossfade a buffer's tail into its head so a noise loop can repeat
    /// without a click at the seam.
    private static func seamless(_ samples: [Float], fade: Int = 600) -> [Float] {
        let n = samples.count
        let f = min(fade, n / 4)
        guard f > 0 else { return samples }
        var out = Array(samples[0..<(n - f)])
        for i in 0..<f {
            let w = Float(i) / Float(f)
            out[i] = samples[i] * w + samples[n - f + i] * (1 - w)
        }
        return out
    }

    // MARK: - one-shots

    private static func render(_ effect: Effect) -> [Float] {
        switch effect {

        case .bounce:
            // The signature sound: a fat rubbery "bloip". The pitch flicks
            // up fast and settles; upper partials die quicker than the
            // fundamental, which is what makes it read as plucked.
            var phase = 0.0
            return tone(duration: 0.20) { t, d, dt in
                let f = 300 + 250 * (1 - exp(-t / 0.018))
                phase += 2 * .pi * f * dt
                let body = sin(phase)
                    + 0.40 * exp(-t / 0.025) * sin(2 * phase)
                    + 0.15 * exp(-t / 0.014) * sin(3 * phase)
                    + 0.18 * sin(0.5 * phase)
                return body * exp(-t / 0.060) * envAD(t, d, 0.0015, 0.05) * 0.52
            }

        case .spring:
            // Brighter and higher than a bounce, with a coil twang.
            var phase = 0.0
            return tone(duration: 0.34) { t, d, dt in
                let f = 400 + 620 * (1 - exp(-t / 0.070)) + 25 * sin(2 * .pi * 22 * t)
                phase += 2 * .pi * f * dt
                let body = sin(phase) + 0.30 * exp(-t / 0.05) * sin(2 * phase)
                return body * exp(-t / 0.110) * envAD(t, d, 0.0015, 0.08) * 0.5
            }

        case .trampoline:
            // Deeper and rounder than the spring, and it rings longer.
            var phase = 0.0
            return tone(duration: 0.45) { t, d, dt in
                let f = 200 + 430 * (1 - exp(-t / 0.130)) + 30 * sin(2 * .pi * 12 * t)
                phase += 2 * .pi * f * dt
                let body = sin(phase)
                    + 0.35 * exp(-t / 0.08) * sin(2 * phase)
                    + 0.12 * exp(-t / 0.04) * sin(3 * phase)
                return body * exp(-t / 0.165) * envAD(t, d, 0.002, 0.11) * 0.5
            }

        case .shoot:
            // Breathy little mouth-pop, pitch falling.
            var phase = 0.0
            var noise = NoiseSource(11)
            return tone(duration: 0.09) { t, d, dt in
                let f = 780 + 720 * exp(-t / 0.022)
                phase += 2 * .pi * f * dt
                let breath = noise.next() * 0.18 * exp(-t / 0.012)
                return (sin(phase) * 0.8 + breath) * exp(-t / 0.028)
                    * envAD(t, d, 0.0015, 0.02) * 0.42
            }

        case .stomp:
            // Squash: wet noise splat over a falling thud.
            var phase = 0.0
            var noise = NoiseSource(22)
            return tone(duration: 0.24) { t, d, dt in
                let f = 90 + 190 * exp(-t / 0.045)
                phase += 2 * .pi * f * dt
                let splat = noise.next() * exp(-t / 0.035) * 0.55
                let thud = sin(phase) * exp(-t / 0.085) * 0.65
                return (splat + thud) * envAD(t, d, 0.002, 0.06) * 0.62
            }

        case .crumble:
            // Three dry wooden cracks as the platform snaps.
            var noise = NoiseSource(33)
            return tone(duration: 0.26) { t, d, _ in
                var v = 0.0
                for b in [0.0, 0.075, 0.155] where t >= b && t < b + 0.05 {
                    v += noise.next() * exp(-(t - b) / 0.010)
                }
                return v * envAD(t, d, 0.001, 0.03) * 0.5
            }

        case .whitePoof:
            // Soft airy puff — a white platform dissolving.
            var noise = NoiseSource(44)
            var lp = 0.0
            return tone(duration: 0.14) { t, d, _ in
                lp += (noise.next() - lp) * 0.25
                return lp * exp(-t / 0.045) * envAD(t, d, 0.004, 0.05) * 0.5
            }

        case .shieldBreak:
            // Deliberately unlike the platform poof: glassy and descending,
            // so losing a shield reads as losing something.
            var phase = 0.0
            var noise = NoiseSource(55)
            return tone(duration: 0.34) { t, d, dt in
                let f = 300 + 900 * exp(-t / 0.10)
                phase += 2 * .pi * f * dt
                let ring = (sin(phase) + 0.5 * sin(2.7 * phase)) * exp(-t / 0.14)
                let shard = noise.next() * exp(-t / 0.05) * 0.45
                return (ring * 0.6 + shard) * envAD(t, d, 0.002, 0.08) * 0.5
            }

        case .fall:
            // The death slide-whistle: a genuine downward glissando.
            var phase = 0.0
            return tone(duration: 0.95) { t, d, dt in
                let f = 190 + 910 * exp(-t / 0.32) + 22 * sin(2 * .pi * 6 * t)
                phase += 2 * .pi * f * dt
                return (sin(phase) + 0.18 * sin(2 * phase))
                    * envAD(t, d, 0.010, 0.22) * 0.46
            }

        case .blackHole:
            // Downward suction spiral.
            var phase = 0.0
            var noise = NoiseSource(66)
            return tone(duration: 0.80) { t, d, dt in
                let f = 90 + 380 * exp(-t / 0.28)
                phase += 2 * .pi * f * dt
                let swirl = sin(phase + 3.0 * sin(2 * .pi * 3.5 * t))
                return (swirl * 0.55 + noise.next() * 0.16 * (1 - t / d))
                    * envAD(t, d, 0.015, 0.18) * 0.5
            }

        case .abduct:
            // Rising, because the UFO pulls you UP. Using the black-hole
            // sound here made the two deaths indistinguishable.
            var phase = 0.0
            var noise = NoiseSource(77)
            return tone(duration: 0.90) { t, d, dt in
                let f = 200 + 700 * (1 - exp(-t / 0.40))
                phase += 2 * .pi * f * dt
                let shimmer = sin(phase + 1.8 * sin(2 * .pi * 11 * t))
                return (shimmer * 0.5 + noise.next() * 0.12 * (t / d))
                    * envAD(t, d, 0.02, 0.20) * 0.48
            }

        case .pickup:
            // Ascending three-note blip; each note is its own windowed
            // oscillator so the steps cannot click.
            let notes: [(start: Double, length: Double, freq: Double)] = [
                (0.000, 0.070, 700), (0.065, 0.070, 940), (0.130, 0.110, 1400),
            ]
            return tone(duration: 0.25) { t, _, _ in
                var v = 0.0
                for n in notes where t >= n.start && t < n.start + n.length {
                    let u = t - n.start
                    v += sin(2 * .pi * n.freq * u) * sin(.pi * u / n.length)
                }
                return v * 0.42
            }

        case .button:
            var phase = 0.0
            return tone(duration: 0.05) { t, d, dt in
                phase += 2 * .pi * 620 * dt
                return sin(phase) * exp(-t / 0.012) * envAD(t, d, 0.001, 0.015) * 0.38
            }

        case .fuse:
            // Runs for exactly as long as the platform stays red, so the
            // sizzle visibly belongs to the thing that is about to explode.
            var noise = NoiseSource(88)
            return tone(duration: Tuning.explodingBoomDelay) { t, d, _ in
                let crackle = noise.next() * (0.35 + 0.65 * abs(sin(2 * .pi * 17 * t)))
                return crackle * (0.5 + 0.5 * (t / d)) * envAD(t, d, 0.03, 0.06) * 0.30
            }

        case .boom:
            var phase = 0.0
            var noise = NoiseSource(99)
            var lp = 0.0
            return tone(duration: 0.50) { t, d, dt in
                lp += (noise.next() - lp) * 0.28
                let f = 55 + 95 * exp(-t / 0.06)
                phase += 2 * .pi * f * dt
                return (sin(phase) * 0.75 + lp * 0.7) * exp(-t / 0.13)
                    * envAD(t, d, 0.003, 0.15) * 0.62
            }
        }
    }

    // MARK: - loops
    //
    // Every component frequency completes a whole number of cycles over the
    // loop length, so the waveform closes on itself and repeats silently.

    private static func render(_ loop: Loop) -> [Float] {
        switch loop {

        case .propeller:
            // Light airy flutter, chopped at blade rate. 0.4s: 100Hz = 40
            // cycles, 25Hz chop = 10 cycles.
            var phase = 0.0
            return tone(duration: 0.40) { t, _, dt in
                phase += 2 * .pi * 100 * dt
                let chop = 0.45 + 0.55 * (0.5 + 0.5 * sin(2 * .pi * 25 * t))
                return (sin(phase) * 0.6 + 0.35 * sin(2 * phase)) * chop * 0.5
            }

        case .jetpack:
            // Sputtery thrust: filtered noise plus a low rumble. Noise will
            // not line up at the seam, so the buffer is crossfaded.
            var noise = NoiseSource(123)
            var lp = 0.0
            var phase = 0.0
            return tone(duration: 0.50) { t, _, dt in
                lp += (noise.next() - lp) * 0.16
                phase += 2 * .pi * 60 * dt
                let surge = 0.78 + 0.22 * sin(2 * .pi * 4 * t)
                return (lp * 1.5 + 0.18 * sin(phase)) * surge * 0.62
            }

        case .monster:
            // Gargled creature warble rather than a plain drone. 0.8s:
            // 150Hz = 120 cycles, 6.25Hz vibrato = 5, 12.5Hz gargle = 10.
            var phase = 0.0
            return tone(duration: 0.80) { t, _, dt in
                let f = 150 + 45 * sin(2 * .pi * 6.25 * t)
                phase += 2 * .pi * f * dt
                let gargle = 0.55 + 0.45 * sin(2 * .pi * 12.5 * t)
                let body = sin(phase) + 0.45 * sin(2 * phase) + 0.20 * sin(3 * phase)
                return body * gargle * 0.36
            }

        case .ufo:
            // Theremin wail. 0.75s: 660Hz = 495 cycles, vibrato 4 cycles.
            var phase = 0.0
            return tone(duration: 0.75) { t, _, dt in
                let f = 660 + 70 * sin(2 * .pi * (4 / 0.75) * t)
                phase += 2 * .pi * f * dt
                return (sin(phase) + 0.12 * sin(2 * phase)) * 0.4
            }
        }
    }

    // MARK: - WAV container

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
