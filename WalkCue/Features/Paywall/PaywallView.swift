import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    let triggeringFeature: PremiumFeature

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    benefits
                    monthlyButton
                    lifetimeButton
                    restoreButton
                    if let error = purchases.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    legalFooter
                }
                .padding()
            }
            .navigationTitle(PricingConfig.paywallTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        PortfolioAnalytics.shared.track(PortfolioEvent.paywallDismissed, [
                            "source": triggeringFeature.rawValue,
                        ])
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            analytics.track(.paywallViewed, properties: ["feature": triggeringFeature.rawValue])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallViewed, [
                "source": triggeringFeature.rawValue,
            ])
        }
        .trackScreen("paywall")
        .onChange(of: purchases.isPremium) { newValue in
            if newValue { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Unlock everything").font(.largeTitle.bold())
            Text(PricingConfig.paywallSubtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PricingConfig.paywallBenefits, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                    Text(item)
                }.font(.body)
            }
        }
    }

    private var monthlyButton: some View {
        Button {
            analytics.track(.purchaseStarted, properties: ["product": "monthly"])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
                "product_id": PricingConfig.monthlyProductID,
            ])
            Task {
                await purchases.purchaseMonthly()
                if purchases.isPremium {
                    analytics.track(.purchaseCompleted, properties: ["product": "monthly"])
                    let product = purchases.monthlyProduct
                    let price = NSDecimalNumber(decimal: product?.price ?? 0).doubleValue
                    let productId = product?.id ?? PricingConfig.monthlyProductID
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": true,
                        "source": triggeringFeature.rawValue,
                        "product_id": productId,
                        "revenue_usd": price,
                        "currency": product?.priceFormatStyle.currencyCode ?? "USD",
                    ])
                    if !UserDefaults.standard.bool(forKey: "posthog.identified") {
                        PortfolioAnalytics.shared.identifyAfterPurchase(productId: productId, revenueUsd: price)
                        UserDefaults.standard.set(true, forKey: "posthog.identified")
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly").font(.headline)
                    Text("Cancel anytime").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(purchases.monthlyDisplayPrice)/mo").font(.headline.monospacedDigit())
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Theme.accent.opacity(0.6), lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Color(.secondarySystemBackground)))
            )
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing)
    }

    private var lifetimeButton: some View {
        Button {
            analytics.track(.purchaseStarted, properties: ["product": "lifetime"])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
                "product_id": PricingConfig.lifetimeProductID,
            ])
            Task {
                await purchases.purchaseLifetime()
                if purchases.isPremium {
                    analytics.track(.purchaseCompleted, properties: ["product": "lifetime"])
                    let product = purchases.lifetimeProduct
                    let price = NSDecimalNumber(decimal: product?.price ?? 0).doubleValue
                    let productId = product?.id ?? PricingConfig.lifetimeProductID
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": false,
                        "source": triggeringFeature.rawValue,
                        "product_id": productId,
                        "revenue_usd": price,
                        "currency": product?.priceFormatStyle.currencyCode ?? "USD",
                    ])
                    if !UserDefaults.standard.bool(forKey: "posthog.identified") {
                        PortfolioAnalytics.shared.identifyAfterPurchase(productId: productId, revenueUsd: price)
                        UserDefaults.standard.set(true, forKey: "posthog.identified")
                    }
                }
            }
        } label: {
            HStack {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lifetime").font(.headline).foregroundStyle(.white)
                        Text("Best value · pay once").font(.caption).foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    Text(purchases.lifetimeDisplayPrice).font(.headline.monospacedDigit()).foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16).padding(.horizontal, 16)
            .background(Theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchases.isPurchasing)
    }

    private var restoreButton: some View {
        Button {
            Task {
                await purchases.restorePurchases()
                if purchases.isPremium { analytics.track(.purchaseRestored) }
            }
        } label: {
            Text("Restore purchases").font(.subheadline).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity)
    }

    private var legalFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly plan is an auto-renewing subscription. Payment is charged to your Apple ID at confirmation and renews each month unless canceled at least 24 hours before the current period ends. Manage or cancel in your Apple ID Account Settings.")
            Text("Lifetime is a one-time non-consumable purchase with no recurring charges.")
            Text("Restore purchases at any time from this screen.")
            HStack(spacing: 12) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·")
                Link("Privacy Policy", destination: URL(string: "https://has-deploy.github.io/walkcue/privacy-policy.html")!)
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.subtle)
    }
}
