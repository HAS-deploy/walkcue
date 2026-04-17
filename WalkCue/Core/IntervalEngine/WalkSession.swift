import Foundation
import Combine
import SwiftUI

/// Runtime controller for an active walk session. Wraps `IntervalEngine` with
/// wall-clock-anchored timing so pause/resume and backgrounding stay accurate.
@MainActor
final class WalkSession: ObservableObject, Identifiable {
    let id = UUID()
    enum State: Equatable { case idle, running, paused, finished }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var currentIntervalIndex: Int? = nil
    @Published private(set) var currentInterval: Interval? = nil
    @Published private(set) var nextInterval: Interval? = nil
    @Published private(set) var remainingInCurrent: TimeInterval = 0

    let engine: IntervalEngine
    let startedAt: Date
    private var accumulatedActive: TimeInterval = 0
    private var lastResumedAt: Date?
    private var lastTickElapsed: TimeInterval = 0
    private var timerCancellable: AnyCancellable?
    private let cues: CueEmitter

    init(routine: Routine, cues: CueEmitter, now: Date = Date()) {
        self.engine = IntervalEngine(routine: routine)
        self.startedAt = now
        self.cues = cues
    }

    func start() {
        guard state == .idle else { return }
        state = .running
        lastResumedAt = Date()
        lastTickElapsed = 0
        refresh()
        cues.emitIntervalStart(engine.currentInterval(at: 0))
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        if let resumed = lastResumedAt {
            accumulatedActive += Date().timeIntervalSince(resumed)
        }
        lastResumedAt = nil
        state = .paused
        stopTimer()
        refresh()
    }

    func resume() {
        guard state == .paused else { return }
        lastResumedAt = Date()
        state = .running
        startTimer()
    }

    func end() -> WalkSummary {
        if state == .running, let resumed = lastResumedAt {
            accumulatedActive += Date().timeIntervalSince(resumed)
            lastResumedAt = nil
        }
        state = .finished
        stopTimer()
        refresh()
        return summary()
    }

    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func currentElapsed() -> TimeInterval {
        if state == .running, let resumed = lastResumedAt {
            return accumulatedActive + Date().timeIntervalSince(resumed)
        }
        return accumulatedActive
    }

    private func tick() {
        let prev = lastTickElapsed
        let now = currentElapsed()
        lastTickElapsed = now
        refresh()

        // Fire cues for any transitions crossed since the last tick.
        let flat = engine.flattenedIntervals
        for nextIdx in engine.transitions(fromElapsed: prev, toElapsed: now) {
            if nextIdx < flat.count {
                cues.emitIntervalStart(flat[nextIdx])
            } else {
                cues.emitSessionComplete()
                state = .finished
                stopTimer()
            }
        }
    }

    private func refresh() {
        let now = currentElapsed()
        self.elapsed = now
        let p = engine.progress(atElapsed: now)
        self.currentIntervalIndex = p.currentIndex
        self.currentInterval = engine.currentInterval(at: now)
        self.nextInterval = engine.nextInterval(at: now)
        self.remainingInCurrent = p.remainingInCurrent
    }

    func summary() -> WalkSummary {
        WalkSummary(
            id: UUID(),
            date: startedAt,
            routineName: engine.routine.name,
            totalSeconds: Int(currentElapsed().rounded()),
            intervalsCompleted: completedIntervalsCount(),
            totalIntervals: engine.flattenedIntervals.count
        )
    }

    private func completedIntervalsCount() -> Int {
        let now = currentElapsed()
        let p = engine.progress(atElapsed: now)
        if p.isComplete { return engine.flattenedIntervals.count }
        return p.currentIndex ?? 0
    }
}

struct WalkSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let routineName: String
    let totalSeconds: Int
    let intervalsCompleted: Int
    let totalIntervals: Int
}
