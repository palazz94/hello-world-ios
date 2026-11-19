import CoreHaptics

/// Short tap per combo, stronger as the combo count grows. Does nothing on devices without haptics.
@MainActor
final class ComboHaptics {
    private var engine: CHHapticEngine?

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func play(combo: Int) {
        guard let engine else { return }
        let intensity = Float(min(1.0, 0.45 + 0.08 * Double(combo)))
        let event = CHHapticEvent(eventType: .hapticTransient,
                                  parameters: [
                                      CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                                      CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                                  ],
                                  relativeTime: 0)
        do {
            try engine.start()
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are cosmetic; ignore failures.
        }
    }
}
