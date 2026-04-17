import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var history: HistoryStore
    @EnvironmentObject var purchases: PurchaseManager

    let onGatedTap: (PremiumFeature) -> Void

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    private var visibleWalks: [WalkSummary] {
        if purchases.isPremium { return history.walks }
        let cutoff = Calendar.current.date(byAdding: .day, value: -PricingConfig.freeHistoryWindow, to: Date()) ?? Date.distantPast
        return history.walks.filter { $0.date >= cutoff }
    }

    var body: some View {
        Group {
            if history.walks.isEmpty {
                ContentUnavailableShim(
                    title: "No walks yet",
                    subtitle: "Tap Start to record your first session.",
                    systemImage: "figure.walk"
                )
            } else {
                List {
                    ForEach(visibleWalks) { walk in
                        walkRow(walk)
                    }
                    if !purchases.isPremium && history.walks.count > visibleWalks.count {
                        Section {
                            UpsellCard(
                                title: "See your full history",
                                message: "Premium unlocks every walk, not just the last \(PricingConfig.freeHistoryWindow) days.",
                                feature: .fullHistory,
                                onTap: onGatedTap
                            )
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func walkRow(_ walk: WalkSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(walk.routineName).font(.body.weight(.semibold))
                Spacer()
                Text(TimeFormat.compactDuration(walk.totalSeconds))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(TimeFormat.formatDate(walk.date))
                Text("·")
                Text(TimeFormat.formatTime(walk.date))
                Text("·")
                Text("\(walk.intervalsCompleted)/\(walk.totalIntervals) intervals")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ContentUnavailableShim: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 48)).foregroundStyle(.secondary)
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
