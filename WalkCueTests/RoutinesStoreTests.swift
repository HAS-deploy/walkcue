import XCTest
@testable import WalkCue

final class RoutinesStoreTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "walkcue.test.\(UUID().uuidString)")!
    }

    func testAddAndPersist() {
        let defaults = freshDefaults()
        let store = RoutinesStore(defaults: defaults)
        XCTAssertTrue(store.customRoutines.isEmpty)
        let r = Routine(name: "A", intervals: [Interval(kind: .brisk, duration: 600)])
        store.addOrUpdate(r)
        let reloaded = RoutinesStore(defaults: defaults)
        XCTAssertEqual(reloaded.customRoutines.count, 1)
        XCTAssertEqual(reloaded.customRoutines.first?.name, "A")
    }

    func testAddOrUpdateReplacesExisting() {
        let store = RoutinesStore(defaults: freshDefaults())
        let id = UUID()
        store.addOrUpdate(Routine(id: id, name: "A", intervals: [Interval(kind: .brisk, duration: 60)]))
        store.addOrUpdate(Routine(id: id, name: "A-updated", intervals: [Interval(kind: .brisk, duration: 120)]))
        XCTAssertEqual(store.customRoutines.count, 1)
        XCTAssertEqual(store.customRoutines.first?.name, "A-updated")
    }

    func testRemoveAtOffsets() {
        let store = RoutinesStore(defaults: freshDefaults())
        store.addOrUpdate(Routine(name: "A", intervals: [Interval(kind: .brisk, duration: 60)]))
        store.addOrUpdate(Routine(name: "B", intervals: [Interval(kind: .brisk, duration: 60)]))
        store.addOrUpdate(Routine(name: "C", intervals: [Interval(kind: .brisk, duration: 60)]))
        store.remove(at: IndexSet(integer: 1))
        XCTAssertEqual(store.customRoutines.map(\.name), ["A", "C"])
    }

    func testAllRoutinesIncludesBuiltIns() {
        let store = RoutinesStore(defaults: freshDefaults())
        XCTAssertGreaterThanOrEqual(store.allRoutines.count, BuiltInRoutines.all.count)
    }
}
