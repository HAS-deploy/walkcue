import Foundation
import Combine

final class HistoryStore: ObservableObject {
    private enum Keys { static let walks = "history.walks" }
    @Published private(set) var walks: [WalkSummary] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.walks = Self.decode([WalkSummary].self, defaults: defaults, key: Keys.walks) ?? []
        // Keep newest first.
        self.walks.sort { $0.date > $1.date }
    }

    func add(_ summary: WalkSummary) {
        walks.insert(summary, at: 0)
        // Cap at 500 to avoid unbounded growth.
        if walks.count > 500 { walks = Array(walks.prefix(500)) }
        persist()
    }

    func remove(id: UUID) {
        walks.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        walks.removeAll()
        persist()
    }

    func walks(onSameDayAs date: Date) -> [WalkSummary] {
        let cal = Calendar.current
        return walks.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    func totalSecondsToday() -> Int {
        walks(onSameDayAs: Date()).reduce(0) { $0 + $1.totalSeconds }
    }

    func sessionsToday() -> Int {
        walks(onSameDayAs: Date()).count
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(walks) {
            defaults.set(data, forKey: Keys.walks)
        }
    }

    private static func decode<T: Decodable>(_ t: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
