import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject var routines: RoutinesStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.analytics) private var analytics
    @Environment(\.cues) private var cues

    let onGatedTap: (PremiumFeature) -> Void

    @State private var activeSession: WalkSession?
    @State private var showingEditor: Bool = false

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    var body: some View {
        List {
            Section("Built-in") {
                ForEach(BuiltInRoutines.all) { routine in
                    routineRow(routine)
                }
            }
            Section {
                ForEach(routines.customRoutines) { routine in
                    routineRow(routine)
                }
                .onDelete { offsets in routines.remove(at: offsets) }
                Button {
                    if gate.canSaveAnotherCustomRoutine(currentCount: routines.customRoutines.count) {
                        showingEditor = true
                    } else {
                        onGatedTap(.customRoutines)
                    }
                } label: {
                    Label("New custom routine", systemImage: "plus.circle")
                }
            } header: {
                Text("Custom")
            } footer: {
                if !purchases.isPremium {
                    Text("Free tier: up to \(PricingConfig.freeCustomRoutineSlots) custom routine. Unlock for unlimited.")
                }
            }
        }
        .navigationTitle("Routines")
        .sheet(isPresented: $showingEditor) {
            RoutineEditorView { new in routines.addOrUpdate(new) }
        }
        .fullScreenCover(item: $activeSession) { session in
            WalkSessionView(session: session)
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        Button {
            let session = WalkSession(routine: routine, cues: cues)
            activeSession = session
            analytics.track(.walkStarted, properties: ["routine": routine.name])
            analytics.track(.presetUsed, properties: ["name": routine.name])
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name).font(.body.weight(.semibold))
                    Text(routineDescription(routine))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func routineDescription(_ routine: Routine) -> String {
        let duration = TimeFormat.compactDuration(Int(routine.totalDuration))
        let repeatsHint = routine.repeats > 1 ? " · ×\(routine.repeats)" : ""
        return "\(duration)\(repeatsHint)"
    }
}

// MARK: - Editor

private struct RoutineEditorView: View {
    let onSave: (Routine) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "My Walk"
    @State private var warmupMin: Int = 3
    @State private var mainMin: Int = 20
    @State private var cooldownMin: Int = 3

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Intervals (minutes)") {
                    Stepper("Warm up: \(warmupMin)", value: $warmupMin, in: 0...15)
                    Stepper("Main: \(mainMin)", value: $mainMin, in: 1...90)
                    Stepper("Cool down: \(cooldownMin)", value: $cooldownMin, in: 0...15)
                }
            }
            .navigationTitle("New Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var intervals: [Interval] = []
                        if warmupMin > 0 { intervals.append(Interval(kind: .warmup, duration: Double(warmupMin * 60))) }
                        intervals.append(Interval(kind: .brisk, duration: Double(mainMin * 60)))
                        if cooldownMin > 0 { intervals.append(Interval(kind: .cooldown, duration: Double(cooldownMin * 60))) }
                        onSave(Routine(name: name, intervals: intervals))
                        dismiss()
                    }
                }
            }
        }
    }
}
