import XCTest
@testable import WalkCue

/// Install-time 7-day Premium trial. Mirrors RoadBinder's
/// `UserEntitlement.isInTrial` semantics, but keyed on a UserDefaults
/// timestamp so reinstall starts a fresh window while in-place app
/// updates do not.
@MainActor
final class InstallTrialTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "walkcue.installTrial.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - 1. Active during the 7-day window

    func testInstallTrialActiveDuringFirstSevenDays() {
        let start = Date()
        let pm = PurchaseManager(defaults: defaults, now: start)
        XCTAssertTrue(pm.installTrialActive, "Trial should be active on day 0")
        XCTAssertTrue(pm.isEntitled)

        // Day 6: still active (we drop at day 7).
        let day6 = Calendar.current.date(byAdding: .day, value: 6, to: start)!
        pm.refreshInstallTrial(now: day6)
        XCTAssertTrue(pm.installTrialActive, "Trial should still be active on day 6")
        XCTAssertTrue(pm.isEntitled)
    }

    // MARK: - 2. Inactive after day 7

    func testInstallTrialInactiveAfterSevenDays() {
        let start = Date()
        let pm = PurchaseManager(defaults: defaults, now: start)
        let day7 = Calendar.current.date(byAdding: .day, value: 7, to: start)!
        pm.refreshInstallTrial(now: day7)
        XCTAssertFalse(pm.installTrialActive, "Trial should expire on day 7")
        XCTAssertFalse(pm.isEntitled, "Without Premium, user should fall back to free tier")

        // Day 30: still inactive.
        let day30 = Calendar.current.date(byAdding: .day, value: 30, to: start)!
        pm.refreshInstallTrial(now: day30)
        XCTAssertFalse(pm.installTrialActive)
        XCTAssertFalse(pm.isEntitled)
    }

    // MARK: - 3. Gate allows Pro features during trial

    func testGateAllowsProFeaturesDuringTrial() {
        let gate = PremiumGate(isEntitled: true)
        // Inside trial, every Pro feature unlocks.
        XCTAssertTrue(gate.isAllowed(.customRoutines))
        XCTAssertTrue(gate.isAllowed(.fullHistory))
        XCTAssertTrue(gate.isAllowed(.multipleReminders))
        // Caps blow past free-tier slots.
        XCTAssertTrue(gate.canSaveAnotherCustomRoutine(currentCount: 99))
        XCTAssertTrue(gate.canEnableAnotherReminder(currentCount: 99))

        // After trial (free tier), the same caps re-engage.
        let freeGate = PremiumGate(isEntitled: false)
        XCTAssertFalse(freeGate.isAllowed(.customRoutines))
        XCTAssertFalse(freeGate.canSaveAnotherCustomRoutine(currentCount: PricingConfig.freeCustomRoutineSlots))
    }

    // MARK: - 4. Routines + history data preserved across the boundary

    func testRoutinesAndHistoryPreservedAfterTrial() {
        // Simulate user data created during the trial against an isolated
        // UserDefaults so we don't pollute the global suite.
        let routinesStore = RoutinesStore(defaults: defaults)
        let customA = Routine(name: "Trial Routine A",
                              intervals: [Interval(kind: .brisk, duration: 600)])
        let customB = Routine(name: "Trial Routine B",
                              intervals: [Interval(kind: .brisk, duration: 900)])
        routinesStore.addOrUpdate(customA)
        routinesStore.addOrUpdate(customB)
        XCTAssertEqual(routinesStore.customRoutines.count, 2,
                       "User can save multiple routines during trial")

        // Stamp history with a walk inside and one outside the free window.
        let historyStore = HistoryStore(defaults: defaults)
        let oldWalk = WalkSummary(id: UUID(),
                                  date: Date().addingTimeInterval(-60 * 60 * 24 * 30),
                                  routineName: "Old",
                                  totalSeconds: 1800,
                                  intervalsCompleted: 3,
                                  totalIntervals: 3)
        let recentWalk = WalkSummary(id: UUID(),
                                     date: Date().addingTimeInterval(-60 * 60 * 24 * 2),
                                     routineName: "Recent",
                                     totalSeconds: 1200,
                                     intervalsCompleted: 3,
                                     totalIntervals: 3)
        historyStore.add(oldWalk)
        historyStore.add(recentWalk)
        let preCount = historyStore.walks.count
        XCTAssertGreaterThanOrEqual(preCount, 2)

        // Trial expires — backdate first-launch to 10 days ago and recompute.
        let start = Date().addingTimeInterval(-60 * 60 * 24 * 10)
        defaults.set(start, forKey: PurchaseManager.firstLaunchKey)
        let pm = PurchaseManager(defaults: defaults, now: Date())
        XCTAssertFalse(pm.installTrialActive, "Trial should be expired")

        // Data is still there — the gate only hides extra rows in the UI,
        // it never deletes the underlying persisted records.
        XCTAssertEqual(routinesStore.customRoutines.count, 2,
                       "Routines created during trial are preserved post-trial")
        XCTAssertEqual(historyStore.walks.count, preCount,
                       "Walk history is not mutated by trial expiration")

        // And both old + recent walks are still in the array (the
        // HistoryView visibility filter happens at render time, not in
        // the store).
        XCTAssertTrue(historyStore.walks.contains(where: { $0.routineName == "Old" }))
        XCTAssertTrue(historyStore.walks.contains(where: { $0.routineName == "Recent" }))
    }
}
