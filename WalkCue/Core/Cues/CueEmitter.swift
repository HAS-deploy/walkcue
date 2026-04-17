import Foundation
import UIKit
import AVFoundation
import SwiftUI

/// Haptic + (optionally) audio cues for interval transitions.
/// No-op if the user disables cues in Settings.
final class CueEmitter {
    private let defaults: UserDefaults
    private var audioPlayer: AVAudioPlayer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var hapticsEnabled: Bool {
        // Default to enabled.
        (defaults.object(forKey: "settings.hapticsEnabled") as? Bool) ?? true
    }
    private var audioEnabled: Bool {
        (defaults.object(forKey: "settings.audioEnabled") as? Bool) ?? true
    }

    func emitIntervalStart(_ interval: Interval?) {
        guard let interval else { return }
        DispatchQueue.main.async {
            if self.hapticsEnabled {
                let style: UIImpactFeedbackGenerator.FeedbackStyle = {
                    switch interval.kind {
                    case .brisk: return .heavy
                    case .warmup, .easy, .custom: return .medium
                    case .cooldown: return .light
                    }
                }()
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()
                generator.impactOccurred()
            }
            if self.audioEnabled {
                self.playSystemTone(for: interval.kind)
            }
        }
    }

    func emitSessionComplete() {
        DispatchQueue.main.async {
            if self.hapticsEnabled {
                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)
            }
            if self.audioEnabled {
                // System "ding" tone
                AudioServicesPlaySystemSound(1025)
            }
        }
    }

    private func playSystemTone(for kind: IntervalKind) {
        // Use built-in system sound IDs; no bundled audio assets required.
        let soundID: SystemSoundID
        switch kind {
        case .warmup: soundID = 1103 // subtle
        case .brisk: soundID = 1113  // tock
        case .easy: soundID = 1104   // soft
        case .cooldown: soundID = 1114
        case .custom: soundID = 1103
        }
        AudioServicesPlaySystemSound(soundID)
    }
}

// Environment injection
private struct CueEmitterKey: EnvironmentKey {
    static let defaultValue = CueEmitter()
}

extension EnvironmentValues {
    var cues: CueEmitter {
        get { self[CueEmitterKey.self] }
        set { self[CueEmitterKey.self] = newValue }
    }
}
