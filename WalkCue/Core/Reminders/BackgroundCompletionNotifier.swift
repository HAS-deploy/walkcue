import Foundation
import UserNotifications

/// Abstraction over `UNUserNotificationCenter` for the bits we need to
/// schedule a one-shot "walk complete" alert at a future date and cancel it
/// later. Keeps `WalkSession` testable without standing up the real
/// notification center.
protocol NotificationScheduling: Sendable {
    /// Returns true if alerts can be presented (authorized / provisional /
    /// ephemeral). Returns false if denied. Requests authorization on first
    /// call when the system status is `.notDetermined`. Idempotent.
    func ensureAuthorization() async -> Bool

    /// Schedule a one-shot local notification with `identifier` firing at
    /// `fireDate`. Replaces any pending request with the same identifier.
    func scheduleOneShot(identifier: String, title: String, body: String, fireDate: Date) async

    /// Cancel any pending notification with `identifier`. No-op if none.
    func cancel(identifier: String)
}

/// Default implementation backed by `UNUserNotificationCenter`.
struct UNNotificationScheduler: NotificationScheduling {
    func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    func scheduleOneShot(identifier: String, title: String, body: String, fireDate: Date) async {
        let center = UNUserNotificationCenter.current()
        // Replace any prior request under the same id (e.g. resume after pause).
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(req)
    }

    func cancel(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Coordinates the "schedule a backup notification at predicted finish time"
/// behavior for a `WalkSession`. The session owns one of these and drives
/// schedule / reschedule / cancel from its lifecycle hooks.
///
/// Behavior:
/// - Only schedules if the user's `Background completion alert` toggle is ON.
/// - Permission is requested lazily on the first schedule call (i.e. the
///   first time the user actually taps Start Walk with the feature enabled),
///   never at cold launch.
/// - Cancellation never requires permission.
final class BackgroundCompletionNotifier: @unchecked Sendable {
    private let scheduler: NotificationScheduling
    private let defaults: UserDefaults

    init(scheduler: NotificationScheduling = UNNotificationScheduler(),
         defaults: UserDefaults = .standard) {
        self.scheduler = scheduler
        self.defaults = defaults
    }

    /// User-facing toggle. Defaults ON to match Settings.
    var isEnabled: Bool {
        (defaults.object(forKey: "settings.backgroundCompletionAlertEnabled") as? Bool) ?? true
    }

    /// Schedule (or replace) the backup notification for `identifier` firing
    /// at `fireDate`. Pulls authorization on first call.
    func schedule(identifier: String, fireDate: Date, totalSeconds: Int) async {
        guard isEnabled else { return }
        guard fireDate.timeIntervalSinceNow > 0.5 else { return }
        guard await scheduler.ensureAuthorization() else { return }
        let minutes = max(1, Int((Double(totalSeconds) / 60.0).rounded()))
        let body = "Walk complete — \(minutes) minute\(minutes == 1 ? "" : "s") done"
        await scheduler.scheduleOneShot(
            identifier: identifier,
            title: "WalkCue",
            body: body,
            fireDate: fireDate
        )
    }

    /// Cancel — safe to call even if nothing is scheduled or permission is
    /// denied.
    func cancel(identifier: String) {
        scheduler.cancel(identifier: identifier)
    }
}
