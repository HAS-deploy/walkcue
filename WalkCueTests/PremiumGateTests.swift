import XCTest
@testable import WalkCue

final class PremiumGateTests: XCTestCase {

    func testFreeUserCanUseQuickStartAndBuiltIns() {
        let gate = PremiumGate(isPremium: false)
        XCTAssertTrue(gate.isAllowed(.quickStart))
        XCTAssertTrue(gate.isAllowed(.builtInRoutines))
    }

    func testFreeUserBlockedFromPaid() {
        let gate = PremiumGate(isPremium: false)
        XCTAssertFalse(gate.isAllowed(.customRoutines))
        XCTAssertFalse(gate.isAllowed(.fullHistory))
        XCTAssertFalse(gate.isAllowed(.multipleReminders))
        XCTAssertFalse(gate.isAllowed(.advancedCues))
    }

    func testPremiumAllowsEverything() {
        let gate = PremiumGate(isPremium: true)
        for f in [PremiumFeature.quickStart, .builtInRoutines, .customRoutines, .fullHistory, .multipleReminders, .advancedCues] {
            XCTAssertTrue(gate.isAllowed(f))
        }
    }

    func testCustomRoutineCap() {
        let free = PremiumGate(isPremium: false)
        XCTAssertTrue(free.canSaveAnotherCustomRoutine(currentCount: 0))
        XCTAssertFalse(free.canSaveAnotherCustomRoutine(currentCount: PricingConfig.freeCustomRoutineSlots))
        XCTAssertTrue(PremiumGate(isPremium: true).canSaveAnotherCustomRoutine(currentCount: 9999))
    }

    func testReminderCap() {
        let free = PremiumGate(isPremium: false)
        XCTAssertTrue(free.canEnableAnotherReminder(currentCount: 0))
        XCTAssertFalse(free.canEnableAnotherReminder(currentCount: PricingConfig.freeReminderSlots))
    }
}
