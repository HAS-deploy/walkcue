import SwiftUI

struct StartView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var routines: RoutinesStore
    @EnvironmentObject var history: HistoryStore
    @Environment(\.analytics) private var analytics
    @Environment(\.cues) private var cues

    let onGatedTap: (PremiumFeature) -> Void

    @State private var activeSession: WalkSession?

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    private var defaultRoutine: Routine {
        routines.customRoutines.first ?? BuiltInRoutines.quickStart
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.stackSpacing) {
                header
                startButton
                todayCard
                recentRoutinesCard
                if !purchases.isPremium { upsellCard }
                disclaimer
            }
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle("WalkCue")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $activeSession) { session in
            WalkSessionView(session: session)
                .environmentObject(history)
                .environment(\.analytics, analytics)
        }
    }

    private var header: some View {
        Text("Tap start for a guided walk. Or pick a routine below.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var startButton: some View {
        Button {
            let session = WalkSession(routine: defaultRoutine, cues: cues)
            activeSession = session
            analytics.track(.walkStarted, properties: ["routine": defaultRoutine.name])
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 48, weight: .bold))
                Text("Start Walk")
                    .font(.title2.bold())
                Text(defaultRoutine.name)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(Theme.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var todayCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Today")
                        .font(.headline)
                    Spacer()
                    Text(TimeFormat.formatDate(Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 20) {
                    statBlock(value: "\(history.totalSecondsToday() / 60)", label: "Minutes walked")
                    statBlock(value: "\(history.sessionsToday())", label: "Sessions")
                    statBlock(value: "\(settings.dailyMinutesGoal)", label: "Goal (min)")
                }
                progressBar
            }
        }
    }

    private var progressBar: some View {
        let goalSeconds = max(1, settings.dailyMinutesGoal * 60)
        let fraction = min(1.0, Double(history.totalSecondsToday()) / Double(goalSeconds))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(Theme.accent).frame(width: geo.size.width * CGFloat(fraction))
            }
        }
        .frame(height: 10)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.semibold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var recentRoutinesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick picks")
                .font(.headline)
            ForEach(Array(BuiltInRoutines.all.prefix(3))) { routine in
                Button {
                    let session = WalkSession(routine: routine, cues: cues)
                    activeSession = session
                    analytics.track(.walkStarted, properties: ["routine": routine.name])
                    analytics.track(.presetUsed, properties: ["name": routine.name])
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name).font(.body.weight(.semibold))
                            Text(TimeFormat.compactDuration(Int(routine.totalDuration)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding()
                    .background(Theme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upsellCard: some View {
        UpsellCard(
            title: "Unlock custom routines",
            message: "Build your own intervals, save unlimited presets, and see all your history.",
            feature: .customRoutines,
            onTap: onGatedTap
        )
    }

    private var disclaimer: some View {
        Text("WalkCue provides walking timers and cues. It is not medical advice.")
            .font(.caption2)
            .foregroundStyle(Theme.subtle)
    }
}

struct UpsellCard: View {
    let title: String
    let message: String
    let feature: PremiumFeature
    let onTap: (PremiumFeature) -> Void

    var body: some View {
        Button { onTap(feature) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "lock.fill").font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                Text("Unlock for a one-time purchase")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
