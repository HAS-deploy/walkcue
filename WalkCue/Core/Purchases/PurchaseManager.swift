import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var installTrialActive: Bool = false
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    /// Distinguish user-cancel / pending / errors for the analytics layer.
    @Published private(set) var lastFailureReason: String?

    private var updatesTask: Task<Void, Never>?
    private let premiumKey = "walkcue.isPremium"
    /// Install-trial bookkeeping key. Set on first launch, then never
    /// rewritten — so reinstalling the app (which clears UserDefaults)
    /// starts a new 7-day window, but app updates do not.
    static let firstLaunchKey = "walkcue.firstLaunchAt"

    /// Days of full-Premium entitlement granted at install time, matching
    /// the StoreKit annual `introductoryOffer` (P1W) on `PricingConfig`.
    /// After this window, the user drops to the free tier with all data
    /// preserved.
    static let installTrialDays: Int = 7

    /// UserDefaults reader for tests + previews; defaults provided so it
    /// can be substituted with an isolated suite.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, now: Date = Date()) {
        self.defaults = defaults
        var initial = defaults.bool(forKey: premiumKey)
        #if DEBUG
        if ProcessInfo.processInfo.environment["WALKCUE_FORCE_PREMIUM"] == "1"
            || defaults.bool(forKey: "WALKCUE_FORCE_PREMIUM") {
            initial = true
        }
        #endif
        self.isPremium = initial
        // Stamp first-launch date on the very first init if not already
        // set, then derive `installTrialActive` immediately so the gate
        // resolves correctly on the first frame.
        if defaults.object(forKey: Self.firstLaunchKey) == nil {
            defaults.set(now, forKey: Self.firstLaunchKey)
        }
        self.installTrialActive = Self.computeTrialActive(
            isPremium: initial,
            firstLaunchAt: defaults.object(forKey: Self.firstLaunchKey) as? Date,
            now: now
        )
    }

    /// Pure helper so tests can exercise the date math without
    /// instantiating a full `PurchaseManager`. Premium users never get
    /// the install-trial flag — they're already entitled via StoreKit.
    static func computeTrialActive(isPremium: Bool, firstLaunchAt: Date?, now: Date = Date()) -> Bool {
        guard !isPremium else { return false }
        guard let start = firstLaunchAt else { return false }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return elapsed < installTrialDays
    }

    /// Recompute `installTrialActive` against the current clock. Call on
    /// app-foreground / scene activation so the flag flips off mid-session
    /// when day 7 elapses.
    func refreshInstallTrial(now: Date = Date()) {
        let start = defaults.object(forKey: Self.firstLaunchKey) as? Date
        self.installTrialActive = Self.computeTrialActive(
            isPremium: isPremium,
            firstLaunchAt: start,
            now: now
        )
    }

    /// Convenience aggregate matching the canonical RoadBinder pattern.
    /// Use this everywhere a Pro action is being gated.
    var isEntitled: Bool { isPremium || installTrialActive }

    deinit { updatesTask?.cancel() }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        observeTransactionUpdates()
    }

    var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? PricingConfig.fallbackLifetimeDisplayPrice
    }

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? PricingConfig.fallbackMonthlyDisplayPrice
    }

    var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? PricingConfig.fallbackAnnualDisplayPrice
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: PricingConfig.allProductIDs)
            self.lifetimeProduct = products.first { $0.id == PricingConfig.lifetimeProductID }
            self.monthlyProduct  = products.first { $0.id == PricingConfig.monthlyProductID }
            self.yearlyProduct   = products.first { $0.id == PricingConfig.annualProductID }
        } catch {
            self.lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseMonthly() async {
        guard let product = monthlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseYearly() async {
        guard let product = yearlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastFailureReason = nil
        do {
            let result = try await product.purchase()
            try await handle(result: result, product: product)
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, error: error)
        }
    }

    private func handle(result: Product.PurchaseResult, product: Product) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            setPremium(true)
            await transaction.finish()
        case .userCancelled:
            lastFailureReason = "user_cancelled"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .userCanceled)
        case .pending:
            self.lastError = "Purchase is pending approval."
            lastFailureReason = "pending_approval"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .pending)
        @unknown default:
            lastFailureReason = "storekit_unknown_case"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .unknown)
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium { self.lastError = "No previous purchases found on this Apple ID." }
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WALKCUE_FORCE_PREMIUM"] == "1"
            || UserDefaults.standard.bool(forKey: "WALKCUE_FORCE_PREMIUM") {
            setPremium(true); return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PricingConfig.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPremium(entitled)
    }

    private func observeTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerifiedUpdate(transaction)
                }
            }
        }
    }

    private func handleVerifiedUpdate(_ transaction: Transaction) async {
        if PricingConfig.allProductIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            setPremium(true)
        } else if transaction.revocationDate != nil {
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        self.isPremium = value
        defaults.set(value, forKey: premiumKey)
        // Premium short-circuits the trial flag — keep them in sync so
        // analytics / paywall logic only ever see one of the two true.
        refreshInstallTrial()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PurchaseError.failedVerification
        case .verified(let value): return value
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Purchase could not be verified." }
    }

    #if DEBUG
    func debugTogglePremium() { setPremium(!isPremium) }
    #endif
}
