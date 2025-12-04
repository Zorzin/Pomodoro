import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    
    // Track the current session ID to validate notifications
    private var currentSessionId: UUID?
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleIntervalEnd(
        seconds: Int,
        intervalType: IntervalType,
        nextType: IntervalType,
        sessionId: UUID
    ) {
        // Only cancel the previous interval notification for this session, not all notifications
        let identifier = "interval-end-\(sessionId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        // Store the session ID
        currentSessionId = sessionId
        
        let content = UNMutableNotificationContent()
        content.title = "\(intervalType.rawValue) Complete!"
        content.body = "Time for \(nextType.rawValue.lowercased())"
        let soundFile = (nextType == .rest) ? "doneit.mp3" : "bell.mp3";
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
        content.interruptionLevel = .timeSensitive
        // Store session ID in userInfo to validate on delivery
        content.userInfo = ["sessionId": sessionId.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(seconds, 1)),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "interval-end-\(sessionId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Failed to schedule notification: \(error)")
            } else {
                print("🔔 Scheduled notification for \(seconds)s, session: \(sessionId.uuidString.prefix(8))")
            }
        }
    }
    
    func sendIntervalChangeNotification(
        type: IntervalType,
        interval: Int,
        total: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = type == .study ? "📚 Study Time" : "☕ Break Time"
        content.body = type == .study
            ? "Focus session \(interval) of \(total)"
            : "Take a short break"
        // Keep default sound for optional immediate heads-up if used again in future
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "interval-change",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🎉 Session Complete!"
        content.body = "Great work! You've completed your study session."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("doneit.mp3"))
        
        let request = UNNotificationRequest(
            identifier: "completion",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // Cancel notifications for a specific session
    func cancelNotifications(forSession sessionId: UUID?) {
        currentSessionId = nil
        
        if let sessionId = sessionId {
            let identifier = "interval-end-\(sessionId.uuidString)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
            print("🔔 Cancelled notifications for session: \(sessionId.uuidString.prefix(8))")
        }
        
        // Also remove any legacy notifications without session ID
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["interval-end"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["interval-end", "completion"])
    }
    
    // Cancel ALL notifications (for app termination scenarios)
    func cancelAllNotifications() {
        currentSessionId = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔔 All notifications cancelled")
    }
}
