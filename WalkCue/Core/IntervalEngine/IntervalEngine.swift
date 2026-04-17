import Foundation

/// Pure, wall-clock-anchored session computation.
/// `IntervalEngine` is stateless: you hand it the routine and a sequence of
/// (start, pauseWindows, now) events and it tells you where in the routine
/// we are. Backgrounding is handled for free because we never rely on timer
/// ticks — elapsed is always `now - start - sum(pause windows)`.
struct IntervalEngine {
    let routine: Routine

    /// Flattened, repeat-expanded list of intervals in play order.
    var flattenedIntervals: [Interval] {
        Array(repeating: routine.intervals, count: routine.repeats).flatMap { $0 }
    }

    var totalDuration: TimeInterval { routine.totalDuration }

    struct Progress: Equatable {
        /// Total elapsed time (exclusive of pauses).
        let elapsed: TimeInterval
        /// Index into `flattenedIntervals`. `nil` once the routine is complete.
        let currentIndex: Int?
        /// Seconds elapsed inside the current interval.
        let elapsedInCurrent: TimeInterval
        /// Seconds remaining in the current interval.
        let remainingInCurrent: TimeInterval
        /// True once the full routine (including all repeats) has completed.
        let isComplete: Bool
    }

    func progress(atElapsed elapsed: TimeInterval) -> Progress {
        let clamped = max(0, elapsed)
        let flat = flattenedIntervals
        var cumulative: TimeInterval = 0
        for (idx, interval) in flat.enumerated() {
            let next = cumulative + interval.duration
            if clamped < next {
                let elapsedInCurrent = clamped - cumulative
                let remainingInCurrent = interval.duration - elapsedInCurrent
                return Progress(elapsed: clamped,
                                currentIndex: idx,
                                elapsedInCurrent: elapsedInCurrent,
                                remainingInCurrent: remainingInCurrent,
                                isComplete: false)
            }
            cumulative = next
        }
        return Progress(elapsed: totalDuration,
                        currentIndex: nil,
                        elapsedInCurrent: 0,
                        remainingInCurrent: 0,
                        isComplete: true)
    }

    func currentInterval(at elapsed: TimeInterval) -> Interval? {
        let p = progress(atElapsed: elapsed)
        guard let idx = p.currentIndex else { return nil }
        return flattenedIntervals[idx]
    }

    func nextInterval(at elapsed: TimeInterval) -> Interval? {
        let p = progress(atElapsed: elapsed)
        guard let idx = p.currentIndex, idx + 1 < flattenedIntervals.count else { return nil }
        return flattenedIntervals[idx + 1]
    }

    /// Returns the indexes of interval transitions that fall strictly between
    /// `fromElapsed` and `toElapsed`. Used to fire cue haptics at transition points.
    func transitions(fromElapsed: TimeInterval, toElapsed: TimeInterval) -> [Int] {
        guard fromElapsed < toElapsed else { return [] }
        let flat = flattenedIntervals
        var out: [Int] = []
        var cumulative: TimeInterval = 0
        for (idx, interval) in flat.enumerated() {
            cumulative += interval.duration
            // transition occurs at the end of interval idx -> into interval idx+1
            if cumulative > fromElapsed && cumulative <= toElapsed {
                // The transition is into the NEXT interval (idx + 1).
                // If idx+1 >= count, that transition is "session complete".
                out.append(idx + 1)
            }
        }
        return out
    }
}
