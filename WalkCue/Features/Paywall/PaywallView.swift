import SwiftUI

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
                    priceBlock
                    benefits
                    purchaseButton
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
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
        .onAppear {
            analytics.track(.paywallViewed, properties: ["feature": triggeringFeature.rawValue])
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallViewed, [
                "source": triggeringFeature.rawValue,
            ])
        }
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

    private var priceBlock: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(purchases.lifetimeDisplayPrice)
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("one-time").font(.headline).foregroundStyle(.secondary)
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

    private var purchaseButton: some View {
        Button {
            analytics.track(.purchaseStarted)
            PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseClick, [
                "source": triggeringFeature.rawValue,
            ])
            Task {
                await purchases.purchaseLifetime()
                if purchases.isPremium {
                    analytics.track(.purchaseCompleted)
                    PortfolioAnalytics.shared.track(PortfolioEvent.paywallPurchaseSuccess, [
                        "is_sub": false,
                        "source": triggeringFeature.rawValue,
                    ])
                }
            }
        } label: {
            HStack {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Unlock for \(purchases.lifetimeDisplayPrice)").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.accent)
            .foregroundStyle(.white)
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
            Text("One-time purchase. No subscriptions or recurring charges.")
            Text("Payment is charged to your Apple ID. Restore purchases at any time from this screen.")
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
