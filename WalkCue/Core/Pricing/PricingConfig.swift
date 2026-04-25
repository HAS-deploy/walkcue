import Foundation

/// Single source of truth for pricing. Update values here, not scattered.
/// Product IDs must match App Store Connect and Configuration.storekit.
enum PricingConfig {
    static let lifetimeProductID  = "com.walkcue.app.lifetime"
    static let monthlyProductID   = "com.walkcue.app.monthly"
    static let subscriptionGroupID = "walkcue_premium"

    static let fallbackLifetimeDisplayPrice = "$8.99"
    static let fallbackMonthlyDisplayPrice  = "$1.99"

    static let allProductIDs: [String] = [monthlyProductID, lifetimeProductID]

    static let paywallTitle    = "Unlock WalkCue"
    static let paywallSubtitle = "Choose monthly or one-time lifetime unlock."

    static let paywallBenefits: [String] = [
        "Unlimited custom routines",
        "Full walk history",
        "Unlimited walk reminders",
    ]

    // Free-tier caps.
    static let freeCustomRoutineSlots = 1
    static let freeReminderSlots = 1
    static let freeHistoryWindow = 7
}
