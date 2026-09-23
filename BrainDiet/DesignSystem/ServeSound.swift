import Foundation
import AVFoundation

// MARK: - ServeSound — the earned sting (2026-08-05).
//
// ⭐ WHY THIS EXISTS. The Breath of the Wild cooking scene is the reference, and
// the research finding that matters is this: the ANIMATION is not what makes that
// moment feel good — the SOUND CUE is. Nintendo engineered a ~5-second jingle
// "to not outstay its welcome," and gave a rare better outcome ("critical cook")
// a DIFFERENT, more triumphant sting. Two lessons, both applied here:
//
//   1. SHORT. Under a second. A reward that repeats every single day must never
//      become something the user learns to dread. Ours is ~0.55s.
//   2. VARIABLE. A normal serve gets `.serve`; finishing the whole plate gets
//      `.fullPlate` — a longer, higher, unmistakably bigger arrival. That's the
//      same variable-reward mechanism a feed uses, except here it is attached to
//      something the user ACTUALLY DID. That's the honest version of it, and it
//      is the only place in the app where we borrow the slot-machine's tool.
//
// ⭐ WHY IT'S SYNTHESISED, not a bundled .wav. A generated audio file would cost
// credits, add weight to a binary we just cut from 152 MB to 13 MB, and lock the
// timbre. Rendering the notes from an envelope-shaped oscillator keeps it a few
// KB of code, tunable in one line, and perfectly consistent across devices.
//
// ⭐ TIMBRE. A pure sine reads as a system alert (cold, digital). Adding a soft
// second harmonic and a fast-attack/long-decay envelope gives a struck-mallet
// quality — marimba/vibraphone — which is what makes BotW's cue read as WARM and
// hand-made rather than as a notification. The intervals rise (a major triad,
// then an octave on the full plate) because ascending pitch is read as
// completion/arrival across essentially all Western music.
//
// RESPECTS SILENCE: plays through `.ambient` so it never interrupts the user's
// music or podcast, and obeys the hardware mute switch. A reward that talks over
// someone's album is a punishment.

@MainActor
final class ServeSound {

    static let shared = ServeSound()

    enum Cue {
        /// One serving plated — the everyday win.
        case serve
        /// The whole plate finished — the rarer, bigger arrival.
        case fullPlate

        /// Frequencies in Hz. Serve = a rising major triad (A4–C#5–E5).
        /// Full plate = the same triad carried up to the octave (A5) — the
        /// listener hears the familiar shape RESOLVE somewhere higher.
        var notes: [Double] {
            switch self {
            case .serve:     return [440.00, 554.37, 659.25]
            case .fullPlate: return [440.00, 554.37, 659.25, 880.00]
            }
        }

        /// Seconds between note onsets. Fast enough to read as one gesture
        /// rather than three separate beeps.
        var spacing: Double { self == .serve ? 0.085 : 0.075 }

        var peakAmplitude: Float { self == .serve ? 0.24 : 0.30 }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Play a cue. Silently no-ops on any audio failure — a missing sound must
    /// never break the serve.
    func play(_ cue: Cue) {
        do {
            try activateIfNeeded()
            guard let buffer = render(cue) else { return }
            player.scheduleBuffer(buffer, completionHandler: nil)
            if !player.isPlaying { player.play() }
        } catch {
            Log.app.error("ServeSound failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func activateIfNeeded() throws {
        guard !started else { return }
        // `.ambient` = mixes with other audio and honours the mute switch.
        // Never `.playback`, which would duck the user's music for a 0.5s chime.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true, options: [])
        try engine.start()
        started = true
    }

    /// Render the whole cue into one buffer: overlapping struck notes, each with
    /// a fast attack and an exponential decay, summed and soft-clipped.
    private func render(_ cue: Cue) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let notes = cue.notes
        let decay = 0.42                                   // seconds a note rings
        let total = cue.spacing * Double(notes.count - 1) + decay
        let frameCount = AVAudioFrameCount(total * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample = 0.0
            for (index, freq) in notes.enumerated() {
                let onset = cue.spacing * Double(index)
                let local = t - onset
                guard local >= 0, local < decay else { continue }
                // Envelope: ~6ms attack (a struck mallet, not a fade-in), then
                // exponential decay — the shape that reads as a physical object
                // being hit rather than a synthesiser being switched on.
                let attack = min(1.0, local / 0.006)
                let env = attack * exp(-local * 7.5)
                // Fundamental + a quieter octave partial = wooden/metallic body.
                let tone = sin(2 * .pi * freq * local)
                         + 0.30 * sin(2 * .pi * freq * 2 * local)
                sample += env * tone
            }
            // Soft clip so stacked notes never crackle.
            let scaled = sample * Double(cue.peakAmplitude) / 1.3
            channel[frame] = Float(tanh(scaled))
        }
        return buffer
    }
}
