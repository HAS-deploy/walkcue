import SwiftUI

extension View {
    /// Applies SwiftUI `.sensoryFeedback` only on iOS 17+. Older OSes get a
    /// no-op so the call site stays a single chained modifier.
    @ViewBuilder
    func hapticSuccess<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.success, trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func hapticError<T: Equatable>(trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.error, trigger: trigger)
        } else {
            self
        }
    }

    @ViewBuilder
    func hapticImpact<T: Equatable>(_ weight: SensoryFeedbackImpactWeight = .medium, trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact(weight: weight.swiftUIWeight), trigger: trigger)
        } else {
            self
        }
    }
}

enum SensoryFeedbackImpactWeight {
    case light, medium, heavy

    @available(iOS 17.0, *)
    var swiftUIWeight: SensoryFeedback.Weight {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
}
