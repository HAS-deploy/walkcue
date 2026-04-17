import Foundation

enum TimeFormat {
    /// Renders a duration as `M:SS` below 1 hour, `H:MM:SS` at or above.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func compactDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m == 0 { return "\(s)s" }
        if s == 0 { return "\(m) min" }
        return "\(m) min \(s)s"
    }

    static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short; f.dateStyle = .none
        return f.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }
}
