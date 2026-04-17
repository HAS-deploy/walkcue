import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let units = "settings.units"
        static let hapticsEnabled = "settings.hapticsEnabled"
        static let audioEnabled = "settings.audioEnabled"
        static let voicePromptsEnabled = "settings.voicePromptsEnabled"
        static let dailyMinutesGoal = "settings.dailyMinutesGoal"
        static let appearance = "settings.appearance"
        static let healthKitOptedIn = "settings.healthKitOptedIn"
    }

    enum Units: String, CaseIterable, Identifiable {
        case metric, imperial
        var id: String { rawValue }
        var label: String { self == .metric ? "Metric (km)" : "Imperial (mi)" }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String {
            switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" }
        }
    }

    @Published var units: Units { didSet { defaults.set(units.rawValue, forKey: Keys.units) } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) } }
    @Published var audioEnabled: Bool { didSet { defaults.set(audioEnabled, forKey: Keys.audioEnabled) } }
    @Published var voicePromptsEnabled: Bool { didSet { defaults.set(voicePromptsEnabled, forKey: Keys.voicePromptsEnabled) } }
    @Published var dailyMinutesGoal: Int { didSet { defaults.set(dailyMinutesGoal, forKey: Keys.dailyMinutesGoal) } }
    @Published var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    @Published var healthKitOptedIn: Bool { didSet { defaults.set(healthKitOptedIn, forKey: Keys.healthKitOptedIn) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.units = Units(rawValue: defaults.string(forKey: Keys.units) ?? "imperial") ?? .imperial
        self.hapticsEnabled = (defaults.object(forKey: Keys.hapticsEnabled) as? Bool) ?? true
        self.audioEnabled = (defaults.object(forKey: Keys.audioEnabled) as? Bool) ?? true
        self.voicePromptsEnabled = (defaults.object(forKey: Keys.voicePromptsEnabled) as? Bool) ?? false
        self.dailyMinutesGoal = (defaults.object(forKey: Keys.dailyMinutesGoal) as? Int) ?? 30
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "system") ?? .system
        self.healthKitOptedIn = defaults.bool(forKey: Keys.healthKitOptedIn)
    }

    var forcedColorScheme: ColorScheme? {
        switch appearance { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}
