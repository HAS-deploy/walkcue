import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let premiumKey = "walkcue.isPremium"

    init() {
        var initial = UserDefaults.standard.bool(forKey: premiumKey)
        #if DEBUG
        if ProcessInfo.processInfo.environment["WALKCUE_FORCE_PREMIUM"] == "1"
            || UserDefaults.standard.bool(forKey: "WALKCUE_FORCE_PREMIUM") {
            initial = true
        }
        #endif
        self.isPremium = initial
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
        observeTransactionUpdates()
    }

    var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? PricingConfig.fallbackLifetimeDisplayPrice
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [PricingConfig.lifetimeProductID])
            self.lifetimeProduct = products.first
        } catch {
            self.lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            try await handle(result: result)
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func handle(result: Product.PurchaseResult) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            setPremium(true)
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            self.lastError = "Purchase is pending approval."
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium {
                self.lastError = "No previous purchases found on this Apple ID."
            }
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["WALKCUE_FORCE_PREMIUM"] == "1"
            || UserDefaults.standard.bool(forKey: "WALKCUE_FORCE_PREMIUM") {
            setPremium(true)
            return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == PricingConfig.lifetimeProductID,
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
        if transaction.productID == PricingConfig.lifetimeProductID,
           transaction.revocationDate == nil {
            setPremium(true)
        } else if transaction.revocationDate != nil {
            setPremium(false)
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        self.isPremium = value
        UserDefaults.standard.set(value, forKey: premiumKey)
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
