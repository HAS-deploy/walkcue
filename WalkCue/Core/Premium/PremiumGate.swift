import Foundation

enum PremiumFeature: String, Identifiable, Hashable {
    case quickStart
    case builtInRoutines
    case customRoutines
    case fullHistory
    case multipleReminders

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickStart: return "Quick Start"
        case .builtInRoutines: return "Built-in Routines"
        case .customRoutines: return "Custom Routines"
        case .fullHistory: return "Full History"
        case .multipleReminders: return "Multiple Reminders"
        }
    }
}

/// Gate decisions for Pro features. `isEntitled` is the canonical input:
/// it collapses (Premium OR inside install-trial) into a single boolean,
/// matching the RoadBinder `EntitlementGate` model. The legacy
/// `isPremium:` initializer is preserved for source-compat with call
/// sites that haven't yet been migrated.
struct PremiumGate {
    let isEntitled: Bool

    init(isEntitled: Bool) {
        self.isEntitled = isEntitled
    }

    /// Legacy initializer — treats `isPremium` as the full entitlement
    /// signal. New call sites should pass `isEntitled:` so the install
    /// trial is honored.
    init(isPremium: Bool) {
        self.isEntitled = isPremium
    }

    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isEntitled { return true }
        switch feature {
        case .quickStart, .builtInRoutines:
            return true
        case .customRoutines, .fullHistory, .multipleReminders:
            return false
        }
    }

    func canSaveAnotherCustomRoutine(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freeCustomRoutineSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
