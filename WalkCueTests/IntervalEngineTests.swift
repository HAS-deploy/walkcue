import XCTest
@testable import WalkCue

final class IntervalEngineTests: XCTestCase {

    private func routine(intervals: [(IntervalKind, TimeInterval)], repeats: Int = 1) -> Routine {
        Routine(name: "Test", intervals: intervals.map { Interval(kind: $0.0, duration: $0.1) }, repeats: repeats)
    }

    func testElapsedZeroReturnsFirstInterval() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 120), (.cooldown, 60)]))
        let p = engine.progress(atElapsed: 0)
        XCTAssertEqual(p.currentIndex, 0)
        XCTAssertEqual(p.elapsedInCurrent, 0, accuracy: 0.01)
        XCTAssertEqual(p.remainingInCurrent, 60, accuracy: 0.01)
        XCTAssertFalse(p.isComplete)
    }

    func testElapsedMidsSecondInterval() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 120), (.cooldown, 60)]))
        let p = engine.progress(atElapsed: 90)
        XCTAssertEqual(p.currentIndex, 1)
        XCTAssertEqual(p.elapsedInCurrent, 30, accuracy: 0.01)
        XCTAssertEqual(p.remainingInCurrent, 90, accuracy: 0.01)
    }

    func testElapsedAtTotalIsComplete() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 120)]))
        let p = engine.progress(atElapsed: 180)
        XCTAssertTrue(p.isComplete)
        XCTAssertNil(p.currentIndex)
    }

    func testRepeatsExpandsIntervals() {
        let engine = IntervalEngine(routine: routine(intervals: [(.brisk, 60), (.easy, 120)], repeats: 3))
        XCTAssertEqual(engine.flattenedIntervals.count, 6)
        XCTAssertEqual(engine.totalDuration, (60 + 120) * 3, accuracy: 0.01)
        let p = engine.progress(atElapsed: 60 + 120 + 30) // into the 2nd loop's brisk interval
        XCTAssertEqual(p.currentIndex, 2)
    }

    func testTransitionsDetectedBetweenTicks() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 120), (.cooldown, 60)]))
        // Tick from 58 -> 62: transitions past boundary at t=60 into index 1.
        let transitions = engine.transitions(fromElapsed: 58, toElapsed: 62)
        XCTAssertEqual(transitions, [1])
    }

    func testTransitionsEmptyWithinInterval() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 120)]))
        XCTAssertTrue(engine.transitions(fromElapsed: 10, toElapsed: 40).isEmpty)
    }

    func testTransitionIncludesCompletion() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60), (.brisk, 60)]))
        // Transition from 119 -> 121 crosses t=120 (end of routine), reports index 2 (= count, = "done")
        let transitions = engine.transitions(fromElapsed: 119, toElapsed: 121)
        XCTAssertEqual(transitions, [2])
    }

    func testNegativeElapsedClampsToZero() {
        let engine = IntervalEngine(routine: routine(intervals: [(.warmup, 60)]))
        let p = engine.progress(atElapsed: -50)
        XCTAssertEqual(p.currentIndex, 0)
        XCTAssertEqual(p.elapsedInCurrent, 0)
    }
}
