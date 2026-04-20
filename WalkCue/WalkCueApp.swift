import SwiftUI

@main
struct WalkCueApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var routines = RoutinesStore()
    @StateObject private var history = HistoryStore()
    private let analytics: AnalyticsService = ConsoleAnalytics()
    private let reminders = ReminderManager()
    private let cues = CueEmitter()

    init() {
        PortfolioAnalytics.shared.start(appName: "walkcue")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(settings)
                .environmentObject(routines)
                .environmentObject(history)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .environment(\.cues, cues)
                .task { await purchases.start() }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
