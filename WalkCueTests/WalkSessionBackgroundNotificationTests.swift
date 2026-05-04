import XCTest
@testable import WalkCue

@MainActor
final class WalkSessionBackgroundNotificationTests: XCTestCase {

    // MARK: - Mock scheduler

    /// Records every call so tests can assert on schedule/cancel order.
    final class MockScheduler: NotificationScheduling, @unchecked Sendable {
        struct ScheduledCall: Equatable {
            let identifier: String
            let title: String
            let body: String
            let fireDate: Date
        }

        private let lock = NSLock()
        private var _scheduled: [ScheduledCall] = []
        private var _cancellations: [String] = []
        var authorizationGranted: Bool = true

        var scheduled: [ScheduledCall] {
            lock.lock(); defer { lock.unlock() }
            return _scheduled
        }
        var cancellations: [String] {
            lock.lock(); defer { lock.unlock() }
            return _cancellations
        }

        func ensureAuthorization() async -> Bool { authorizationGranted }

        func scheduleOneShot(identifier: String, title: String, body: String, fireDate: Date) async {
            lock.lock()
            _scheduled.append(ScheduledCall(identifier: identifier, title: title, body: body, fireDate: fireDate))
            lock.unlock()
        }

        func cancel(identifier: String) {
            lock.lock()
            _cancellations.append(identifier)
            lock.unlock()
        }
    }

    // MARK: - Helpers

    private func freshDefaults(toggleEnabled: Bool = true) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "walkcue.test.bgnotif.\(UUID().uuidString)")!
        defaults.set(toggleEnabled, forKey: "settings.backgroundCompletionAlertEnabled")
        return defaults
    }

    private func makeSession(
        scheduler: MockScheduler,
        defaults: UserDefaults,
        intervals: [(IntervalKind, TimeInterval)] = [(.warmup, 60), (.brisk, 120), (.cooldown, 60)]
    ) -> WalkSession {
        let routine = Routine(name: "Test",
                              intervals: intervals.map { Interval(kind: $0.0, duration: $0.1) })
        let notifier = BackgroundCompletionNotifier(scheduler: scheduler, defaults: defaults)
        return WalkSession(routine: routine, cues: CueEmitter(defaults: defaults), notifier: notifier)
    }

    /// Lets the `Task { await notifier.schedule(...) }` fire-and-forget chain
    /// drain so we can read MockScheduler state.
    private func drainTasks() async {
        // Several yields cover: outer Task spawn, ensureAuthorization await,
        // scheduleOneShot await.
        for _ in 0..<8 { await Task.yield() }
    }

    // MARK: - Tests

    func testSchedulesOnStart() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults()
        let session = makeSession(scheduler: scheduler, defaults: defaults)

        let before = Date()
        session.start()
        await drainTasks()

        XCTAssertEqual(scheduler.scheduled.count, 1, "Start should schedule exactly one notification")
        let call = scheduler.scheduled[0]
        XCTAssertTrue(call.identifier.hasPrefix("walkcue.session."))
        XCTAssertFalse(call.body.isEmpty)
        XCTAssertTrue(call.body.contains("Walk complete"), "Body should match in-app post-session cue")
        // Predicted finish ≈ now + 240s (60+120+60).
        let delta = call.fireDate.timeIntervalSince(before)
        XCTAssertEqual(delta, 240, accuracy: 5.0)
    }

    func testCancelsOnPause() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults()
        let session = makeSession(scheduler: scheduler, defaults: defaults)

        session.start()
        await drainTasks()
        XCTAssertEqual(scheduler.scheduled.count, 1)
        let scheduledID = scheduler.scheduled[0].identifier

        session.pause()
        XCTAssertEqual(scheduler.cancellations.last, scheduledID,
                       "Pause should cancel the scheduled notification")
    }

    func testReschedulesOnResume() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults()
        let session = makeSession(scheduler: scheduler, defaults: defaults)

        session.start()
        await drainTasks()
        let firstCall = scheduler.scheduled[0]

        session.pause()
        // Sleep briefly so the resumed predicted-finish is measurably later.
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        session.resume()
        await drainTasks()

        XCTAssertEqual(scheduler.scheduled.count, 2,
                       "Resume should reschedule a fresh predicted-finish notification")
        let secondCall = scheduler.scheduled[1]
        XCTAssertEqual(firstCall.identifier, secondCall.identifier,
                       "Same session reuses one identifier so the system replaces the prior")
        XCTAssertGreaterThan(secondCall.fireDate, firstCall.fireDate,
                             "Predicted finish after resume should shift later than original")
    }

    func testNoDoubleFireOnLegitimateForegroundCompletion() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults()
        // Use very short intervals so the foreground timer can drive completion
        // within the test's wall clock.
        let session = makeSession(
            scheduler: scheduler,
            defaults: defaults,
            intervals: [(.warmup, 1), (.brisk, 1)]
        )

        session.start()
        await drainTasks()
        XCTAssertEqual(scheduler.scheduled.count, 1)
        let scheduledID = scheduler.scheduled[0].identifier

        // Wait for the routine to complete in the foreground (~2.5s incl. tick).
        let completed = await waitForFinish(session: session, timeout: 4.0)
        XCTAssertTrue(completed, "Session should reach .finished via the foreground tick")

        XCTAssertTrue(scheduler.cancellations.contains(scheduledID),
                      "Foreground completion must cancel the backup notification")
    }

    func testToggleOffSuppressesScheduling() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults(toggleEnabled: false)
        let session = makeSession(scheduler: scheduler, defaults: defaults)

        session.start()
        await drainTasks()

        XCTAssertTrue(scheduler.scheduled.isEmpty,
                      "When toggle is OFF, no backup notification should be scheduled")
    }

    func testCancelBackgroundCompletionIfFinishedNoOpsWhileRunning() async {
        let scheduler = MockScheduler()
        let defaults = freshDefaults()
        let session = makeSession(scheduler: scheduler, defaults: defaults)

        session.start()
        await drainTasks()
        let priorCancellations = scheduler.cancellations.count

        session.cancelBackgroundCompletionIfFinished()

        XCTAssertEqual(scheduler.cancellations.count, priorCancellations,
                       "Returning to foreground while running must NOT cancel — the alert is still needed")
    }

    // MARK: - Wait helper

    private func waitForFinish(session: WalkSession, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if session.state == .finished { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return session.state == .finished
    }
}
