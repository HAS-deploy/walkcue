import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var history: HistoryStore
    @Environment(\.analytics) private var analytics
    @Environment(\.reminders) private var reminders

    @State private var showPaywall = false
    @State private var walkReminderEnabled = false
    @State private var walkReminderTime: Date = TimeFormat.combine(hour: 8, minute: 0)
    @State private var reminderAuthStatus: ReminderManager.AuthStatus = .notDetermined
    private let healthKit = HealthKitManager()

    var body: some View {
        Form {
            premiumSection
            remindersSection
            goalsSection
            cuesSection
            healthSection
            displaySection
            aboutSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .task {
            reminderAuthStatus = await reminders.currentStatus()
            walkReminderEnabled = await reminders.pendingIdentifiers().contains("walk_reminder")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeringFeature: .multipleReminders)
                .environmentObject(purchases)
        }
    }

    // MARK: - Sections

    private var premiumSection: some View {
        Section {
            if purchases.isPremium {
                Label("Premium unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Unlock everything").font(.headline)
                            Text("One-time \(purchases.lifetimeDisplayPrice). No subscription.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                Button("Restore purchases") { Task { await purchases.restorePurchases() } }
            }
        } header: { Text("WalkCue Premium") }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            Toggle("Daily walk reminder", isOn: $walkReminderEnabled)
                .onChange(of: walkReminderEnabled) { enabled in
                    Task { await handleReminderToggle(enabled) }
                }
            if walkReminderEnabled {
                DatePicker("Time", selection: $walkReminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: walkReminderTime) { _ in Task { await reschedule() } }
            }
            if reminderAuthStatus == .denied {
                Text("Notifications are disabled for WalkCue. Enable them in Settings to use reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: { Text("Reminders") } footer: {
            Text("Free tier: \(PricingConfig.freeReminderSlots) reminder. Unlock for unlimited.")
        }
    }

    private var goalsSection: some View {
        Section {
            Stepper("Daily walk goal: \(settings.dailyMinutesGoal) min",
                    value: $settings.dailyMinutesGoal, in: 5...120, step: 5)
        } header: { Text("Goals") } footer: {
            Text("Minutes of active walking per day. Progress resets at midnight.")
        }
    }

    private var cuesSection: some View {
        Section {
            Toggle("Haptic cues", isOn: $settings.hapticsEnabled)
            Toggle("Audio cues", isOn: $settings.audioEnabled)
        } header: { Text("Cues") } footer: {
            Text("Cues play at each interval transition (e.g. warm up → brisk).")
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        if healthKit.isAvailable {
            Section {
                Toggle("Use Apple Health step count", isOn: $settings.healthKitOptedIn)
                    .onChange(of: settings.healthKitOptedIn) { enabled in
                        if enabled { Task { _ = await healthKit.requestStepsAuthorization() } }
                    }
            } header: { Text("Apple Health") } footer: {
                Text("Optional. WalkCue works without Health access.")
            }
        }
    }

    private var displaySection: some View {
        Section {
            Picker("Units", selection: $settings.units) {
                ForEach(SettingsStore.Units.allCases) { u in Text(u.label).tag(u) }
            }
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases) { a in Text(a.label).tag(a) }
            }
        } header: { Text("Display") }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy policy", destination: URL(string: "https://has-deploy.github.io/walkcue/privacy-policy.html")!)
            Link("Support", destination: URL(string: "https://has-deploy.github.io/walkcue/support.html")!)
            LabeledContent("Version", value: Bundle.main.marketingVersion)
            LabeledContent("Walks recorded", value: "\(history.walks.count)")
        } header: { Text("About") } footer: {
            Text("WalkCue is a walking timer and cue app. Not medical advice.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(purchases.isPremium ? "Disable premium (debug)" : "Enable premium (debug)") {
                purchases.debugTogglePremium()
            }
        }
    }
    #endif

    private func handleReminderToggle(_ enabled: Bool) async {
        guard enabled else {
            reminders.cancel(identifier: "walk_reminder")
            return
        }
        let gate = PremiumGate(isPremium: purchases.isPremium)
        let pending = await reminders.pendingIdentifiers()
        let others = pending.filter { $0 != "walk_reminder" }.count
        if !gate.canEnableAnotherReminder(currentCount: others) {
            walkReminderEnabled = false
            showPaywall = true
            return
        }
        if reminderAuthStatus == .notDetermined {
            let granted = await reminders.requestAuthorization()
            reminderAuthStatus = granted ? .authorized : .denied
            if !granted { walkReminderEnabled = false; return }
        } else if reminderAuthStatus == .denied {
            walkReminderEnabled = false
            return
        }
        await reschedule()
        analytics.track(.reminderEnabled, properties: ["kind": "walk"])
    }

    private func reschedule() async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: walkReminderTime)
        let h = comps.hour ?? 8; let m = comps.minute ?? 0
        do {
            try await reminders.scheduleDailyReminder(
                identifier: "walk_reminder",
                title: "Time to walk",
                body: "A short walk now keeps your streak going.",
                hour: h, minute: m
            )
        } catch { walkReminderEnabled = false }
    }
}

private extension Bundle {
    var marketingVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

extension TimeFormat {
    static func combine(hour: Int, minute: Int, on day: Date = Date()) -> Date {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: day)
        c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c) ?? day
    }
}
