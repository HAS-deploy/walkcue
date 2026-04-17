import Foundation

/// Single source of truth for pricing. Change values here, not scattered.
enum PricingConfig {
    static let lifetimeProductID = "com.walkcue.app.lifetime"
    static let fallbackLifetimeDisplayPrice = "$8.99"

    static let paywallTitle = "Unlock WalkCue"
    static let paywallSubtitle = "One-time purchase. No subscriptions."

    static let paywallBenefits: [String] = [
        "Unlimited custom routines",
        "Full walk history",
        "Advanced cue packs",
        "Multiple bedtime & walk reminders",
        "Saved presets and favorites"
    ]

    /// Free-tier caps.
    static let freeCustomRoutineSlots = 1
    static let freeReminderSlots = 1
    /// How many past walks a free user can see. Premium shows everything.
    static let freeHistoryWindow = 7
}
