import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Optional HealthKit integration. The app works without any permissions.
/// Call sites should handle the "unavailable" state gracefully.
struct HealthKitManager {
    enum HKStatus { case unavailable, notDetermined, authorized, denied }

    #if canImport(HealthKit)
    private let store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    func requestStepsAuthorization() async -> HKStatus {
        #if canImport(HealthKit)
        guard let store, isAvailable else { return .unavailable }
        let stepType = HKQuantityType(.stepCount)
        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            // HealthKit hides whether the user actually granted read access;
            // we return "authorized" optimistically and let queries tell the real story.
            return .authorized
        } catch {
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    func stepsToday() async -> Int {
        #if canImport(HealthKit)
        guard let store, isAvailable else { return 0 }
        let type = HKQuantityType(.stepCount)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let total = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(total))
            }
            store.execute(q)
        }
        #else
        return 0
        #endif
    }
}
