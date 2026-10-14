import AVFoundation

enum SoundEffect: CaseIterable {
    case reveal
    case flag
    /// Once per second while the timer runs, like the original.
    case tick
    case explosion
    case win
}

/// Something that can play an effect. Whether it *should* is decided by the caller
/// (`AppSettings.allowsSound`), so tests can swap in a recorder.
@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
}

/// Plays short effects synthesized at launch, so there are no audio assets to ship or license.
/// Uses the ambient audio category: it respects the silent switch and mixes with her music.
@MainActor
final class SoundEffects: SoundPlaying {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    /// A few voices so a click doesn't cut off the explosion.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    /// Effects that couldn't be built are simply missing, so they play silently.
    private lazy var buffers: [SoundEffect: AVAudioPCMBuffer] = {
        guard let format else { return [:] }
        return SoundEffect.allCases.reduce(into: [:]) { buffers, effect in
            buffers[effect] = Synth.buffer(for: effect, format: format)
        }
    }()

    func play(_ effect: SoundEffect) {
        guard startEngineIfNeeded(), let buffer = buffers[effect] else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Set up lazily so a player who never turns sound on never touches the audio session.
    private func startEngineIfNeeded() -> Bool {
        guard let format else { return false }
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            for _ in 0..<4 {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                players.append(player)
            }
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return true
    }
}

/// Tiny additive/noise synthesizer for the effects.
private enum Synth {
    static func buffer(for effect: SoundEffect, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let samples: [Float] = switch effect {
        case .reveal:
            tone(1_400, duration: 0.03, decay: 110, gain: 0.22, rate: rate)
        case .flag:
            tone(660, duration: 0.045, decay: 50, gain: 0.25, rate: rate)
                + tone(990, duration: 0.06, decay: 50, gain: 0.25, rate: rate)
        case .tick:
            tone(2_800, duration: 0.015, decay: 350, gain: 0.18, rate: rate)
        case .explosion:
            explosion(rate: rate)
        case .win:
            [523.25, 659.25, 783.99].flatMap { tone($0, duration: 0.11, decay: 10, gain: 0.22, rate: rate) }
                + tone(1_046.5, duration: 0.4, decay: 6, gain: 0.22, rate: rate)
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, sample) in samples.enumerated() { channel[i] = sample }
        return buffer
    }

    /// A sine with a soft attack, exponential decay and a short release so it never clicks.
    private static func tone(_ frequency: Double, duration: Double, decay: Double, gain: Float, rate: Double) -> [Float] {
        let count = Int(duration * rate)
        return (0..<count).map { i in
            let t = Double(i) / rate
            let envelope = exp(-t * decay) * min(1, t * 2_000) * min(1, (duration - t) * 300)
            return Float(sin(2 * .pi * frequency * t) * envelope) * gain
        }
    }

    /// Low-passed noise whose cutoff falls as it decays, over a low thump.
    private static func explosion(rate: Double) -> [Float] {
        let duration = 0.9
        var lowPassed = 0.0
        return (0..<Int(duration * rate)).map { i in
            let t = Double(i) / rate
            let cutoff = 0.02 + 0.25 * exp(-t * 6)
            lowPassed += cutoff * (Double.random(in: -1...1) - lowPassed)
            let rumble = lowPassed * exp(-t * 4.5) * 1.6
            let thump = sin(2 * .pi * 55 * t) * exp(-t * 8) * 0.5
            let fade = min(1, t * 500) * min(1, (duration - t) * 50)
            return Float((rumble + thump) * fade) * 0.6
        }
    }
}
