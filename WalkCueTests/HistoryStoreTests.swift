import XCTest
@testable import WalkCue

final class HistoryStoreTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "walkcue.test.hist.\(UUID().uuidString)")!
    }

    func testAddAndPersist() {
        let defaults = freshDefaults()
        let store = HistoryStore(defaults: defaults)
        let summary = WalkSummary(id: UUID(), date: Date(), routineName: "Test", totalSeconds: 1200, intervalsCompleted: 3, totalIntervals: 3)
        store.add(summary)
        let reloaded = HistoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.walks.count, 1)
        XCTAssertEqual(reloaded.walks.first?.totalSeconds, 1200)
    }

    func testTotalSecondsTodayFiltersCorrectly() {
        let store = HistoryStore(defaults: freshDefaults())
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        store.add(WalkSummary(id: UUID(), date: today, routineName: "A", totalSeconds: 600, intervalsCompleted: 1, totalIntervals: 1))
        store.add(WalkSummary(id: UUID(), date: today, routineName: "B", totalSeconds: 300, intervalsCompleted: 1, totalIntervals: 1))
        store.add(WalkSummary(id: UUID(), date: yesterday, routineName: "C", totalSeconds: 9999, intervalsCompleted: 1, totalIntervals: 1))
        XCTAssertEqual(store.totalSecondsToday(), 900)
        XCTAssertEqual(store.sessionsToday(), 2)
    }

    func testCapsAt500() {
        let store = HistoryStore(defaults: freshDefaults())
        for i in 0..<520 {
            store.add(WalkSummary(id: UUID(), date: Date().addingTimeInterval(-Double(i)), routineName: "x", totalSeconds: 60, intervalsCompleted: 1, totalIntervals: 1))
        }
        XCTAssertLessThanOrEqual(store.walks.count, 500)
    }
}
