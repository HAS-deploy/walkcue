import Foundation

enum PremiumFeature: String, Identifiable, Hashable {
    case quickStart
    case builtInRoutines
    case customRoutines
    case fullHistory
    case multipleReminders
    case advancedCues

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickStart: return "Quick Start"
        case .builtInRoutines: return "Built-in Routines"
        case .customRoutines: return "Custom Routines"
        case .fullHistory: return "Full History"
        case .multipleReminders: return "Multiple Reminders"
        case .advancedCues: return "Advanced Cues"
        }
    }
}

struct PremiumGate {
    let isPremium: Bool

    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
        switch feature {
        case .quickStart, .builtInRoutines:
            return true
        case .customRoutines, .fullHistory, .multipleReminders, .advancedCues:
            return false
        }
    }

    func canSaveAnotherCustomRoutine(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeCustomRoutineSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
