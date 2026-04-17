import Foundation
import Combine

final class RoutinesStore: ObservableObject {
    private enum Keys { static let customRoutines = "routines.custom" }
    @Published private(set) var customRoutines: [Routine] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.customRoutines = Self.decode([Routine].self, defaults: defaults, key: Keys.customRoutines) ?? []
    }

    /// All routines available to the user: built-ins first, then custom.
    var allRoutines: [Routine] { BuiltInRoutines.all + customRoutines }

    func addOrUpdate(_ routine: Routine) {
        if let idx = customRoutines.firstIndex(where: { $0.id == routine.id }) {
            customRoutines[idx] = routine
        } else {
            customRoutines.append(routine)
        }
        persist()
    }

    func remove(id: UUID) {
        customRoutines.removeAll { $0.id == id }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) where customRoutines.indices.contains(i) {
            customRoutines.remove(at: i)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customRoutines) {
            defaults.set(data, forKey: Keys.customRoutines)
        }
    }

    private static func decode<T: Decodable>(_ t: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
