import Foundation

enum IntervalKind: String, Codable, Hashable, CaseIterable {
    case warmup, brisk, easy, cooldown, custom

    var displayName: String {
        switch self {
        case .warmup: return "Warm up"
        case .brisk: return "Brisk"
        case .easy: return "Easy"
        case .cooldown: return "Cool down"
        case .custom: return "Custom"
        }
    }

    /// Suggested pace copy shown to the user; pure text, no prescription.
    var paceHint: String {
        switch self {
        case .warmup: return "Comfortable starting pace"
        case .brisk: return "Faster than conversational"
        case .easy: return "Conversational pace"
        case .cooldown: return "Slow down and relax"
        case .custom: return ""
        }
    }
}

struct Interval: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: IntervalKind
    /// Duration in seconds.
    var duration: TimeInterval
    /// Optional custom label; falls back to kind.displayName.
    var customLabel: String?

    init(id: UUID = UUID(), kind: IntervalKind, duration: TimeInterval, customLabel: String? = nil) {
        self.id = id
        self.kind = kind
        self.duration = max(1, duration)
        self.customLabel = customLabel
    }

    var label: String { customLabel ?? kind.displayName }
}

struct Routine: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var intervals: [Interval]
    /// How many times to repeat the interval block. 1 = play once.
    var repeats: Int
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, intervals: [Interval], repeats: Int = 1, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.repeats = max(1, repeats)
        self.isBuiltIn = isBuiltIn
    }

    var totalDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration } * Double(repeats)
    }
}

/// The canonical set of built-in routines shipped with the app.
/// Built-ins are always available (no premium gate) so the app works out of the box.
enum BuiltInRoutines {
    static let quickStart = Routine(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!,
        name: "Quick 20-Minute Walk",
        intervals: [
            Interval(kind: .warmup, duration: 3 * 60),
            Interval(kind: .easy, duration: 14 * 60),
            Interval(kind: .cooldown, duration: 3 * 60),
        ],
        isBuiltIn: true
    )

    static let beginner = Routine(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!,
        name: "Beginner 15 Minutes",
        intervals: [
            Interval(kind: .warmup, duration: 3 * 60),
            Interval(kind: .easy, duration: 9 * 60),
            Interval(kind: .cooldown, duration: 3 * 60),
        ],
        isBuiltIn: true
    )

    static let fatBurn = Routine(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!,
        name: "Brisk Intervals 30 Minutes",
        intervals: [
            Interval(kind: .warmup, duration: 5 * 60),
            Interval(kind: .brisk, duration: 60),
            Interval(kind: .easy, duration: 2 * 60),
        ],
        repeats: 6,
        isBuiltIn: true
    )

    static let treadmill = Routine(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000A004")!,
        name: "Treadmill 25 Minutes",
        intervals: [
            Interval(kind: .warmup, duration: 5 * 60),
            Interval(kind: .brisk, duration: 15 * 60),
            Interval(kind: .cooldown, duration: 5 * 60),
        ],
        isBuiltIn: true
    )

    static let recovery = Routine(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000A005")!,
        name: "Recovery 15 Minutes",
        intervals: [
            Interval(kind: .easy, duration: 15 * 60),
        ],
        isBuiltIn: true
    )

    static let all: [Routine] = [quickStart, beginner, fatBurn, treadmill, recovery]
}
