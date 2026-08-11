import Foundation
import Observation
import UserNotifications

/// Schedules the optional once-a-day "edition is ready" reminder.
@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var isEnabled: Bool

    /// Only the hour and minute components matter.
    var reminderTime: Date {
        didSet {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            UserDefaults.standard.set(parts.hour ?? 8, forKey: "reminderHour")
            UserDefaults.standard.set(parts.minute ?? 0, forKey: "reminderMinute")
            if isEnabled { schedule() }
        }
    }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        let hour = UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 8
        let minute = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 0
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        reminderTime = Calendar.current.date(from: parts) ?? Date()
    }

    /// Turns the reminder on or off. Returns false if the user has denied
    /// notification permission, so the UI can point them at Settings.
    @discardableResult
    func setEnabled(_ on: Bool) async -> Bool {
        guard on else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: "reminderEnabled")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-edition"])
            return true
        }

        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isEnabled = granted
        UserDefaults.standard.set(granted, forKey: "reminderEnabled")
        if granted { schedule() }
        return granted
    }

    private func schedule() {
        let content = UNMutableNotificationContent()
        content.title = "The Nuus"
        content.body = "Today's edition is ready — your bite-sized digest awaits."
        content.sound = .default

        var parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        parts.second = 0

        let request = UNNotificationRequest(
            identifier: "daily-edition",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
