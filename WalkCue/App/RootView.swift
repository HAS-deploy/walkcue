import SwiftUI

struct RootView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selection: Tab = RootView.initialTab()
    @State private var paywallTrigger: PremiumFeature?

    enum Tab: Hashable { case start, routines, history, settings }

    static func initialTab() -> Tab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "WALKCUE_INITIAL_TAB")
            ?? ProcessInfo.processInfo.environment["WALKCUE_INITIAL_TAB"] {
        case "routines": return .routines
        case "history": return .history
        case "settings": return .settings
        default: return .start
        }
        #else
        return .start
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                StartView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Start", systemImage: "figure.walk") }
            .tag(Tab.start)

            NavigationStack {
                RoutinesView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }
            .tag(Tab.routines)

            NavigationStack {
                HistoryView(onGatedTap: { paywallTrigger = $0 })
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(Tab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .sheet(item: $paywallTrigger) { feature in
            PaywallView(triggeringFeature: feature)
                .environmentObject(purchases)
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "WALKCUE_SHOW_PAYWALL") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    paywallTrigger = .customRoutines
                }
            }
            #endif
        }
    }
}
