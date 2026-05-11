import Foundation

/// Single source of truth for pricing, product IDs, display copy, and the
/// 3.1.2(a) disclosure block. The paywall, `Configuration.storekit`, and
/// the ASC-side products must all agree with these constants.
///
/// Trial-determination model (portfolio-wide pattern):
///   - Annual product carries a StoreKit `introductoryOffer` of paymentMode
///     `free` for `P1W` (7 days). WalkCue uses 1 week because walks are a
///     daily-use habit that forms within a week.
///   - Monthly product carries NO intro offer.
///   - Forfeiture sentence is rendered inline next to the trial AND in the
///     disclosure block per the canonical 3.1.2 pattern.
enum PricingConfig {
    // Product IDs (legacy names kept for source-compat with existing call
    // sites; mirror `ProductIDs` enum for the canonical lookup).
    static let lifetimeProductID = ProductIDs.lifetime
    static let monthlyProductID  = ProductIDs.monthly
    static let annualProductID   = ProductIDs.yearly
    static let subscriptionGroupID = "walkcue_premium"

    // Display-only fallbacks used when StoreKit `Product.displayPrice` is
    // unavailable (sandbox flake / cold launch). Real prices come from
    // runtime `Product.displayPrice`.
    static let fallbackLifetimeDisplayPrice = "$8.99"
    static let fallbackMonthlyDisplayPrice  = "$1.99"
    static let fallbackAnnualDisplayPrice   = "$14.99"

    static let monthlyDisplayPrice = "$1.99"
    static let annualDisplayPrice  = "$14.99"

    static let allProductIDs: [String] = ProductIDs.all

    static let paywallTitle    = "Unlock WalkCue"
    static let paywallSubtitle = "Pick yearly with a 7-day free trial, monthly, or one-time lifetime unlock."

    static let paywallBenefits: [String] = [
        "Unlimited custom routines",
        "Full walk history",
        "Unlimited walk reminders",
    ]

    /// Trial-determination: 7-day free trial introductory offer on annual.
    /// Mirrors `Configuration.storekit` and the ASC-side
    /// `subscriptionIntroductoryOffers` records — the constant + the
    /// StoreKit file + the paywall copy + the ASC product must agree exactly.
    static let annualTrialDays: Int = 7
    static let annualTrialDescription: String = "7-day free trial, then $14.99/year"

    /// 3.1.2(a) disclosures rendered verbatim by the paywall.
    static let disclosurePaymentCharged =
        "Payment will be charged to your Apple ID account at confirmation of purchase."
    static let disclosureAutoRenew =
        "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    static let disclosureRenewalCharge =
        "Your account will be charged for renewal within 24 hours prior to the end of the current period."
    static let disclosureManage =
        "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."
    static let disclosureFreeTrial =
        "If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends."

    /// URLs rendered as tappable links in the paywall and ASC metadata.
    static let privacyPolicyURL = "https://has-deploy.github.io/walkcue/privacy-policy.html"
    static let appleStdEULAURL  = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    // Free-tier caps.
    static let freeCustomRoutineSlots = 1
    static let freeReminderSlots = 1
    static let freeHistoryWindow = 7
}
