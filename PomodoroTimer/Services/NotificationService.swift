import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    
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
        nextType: IntervalType
    ) {
        cancelAllNotifications()
        
        let content = UNMutableNotificationContent()
        content.title = "\(intervalType.rawValue) Complete!"
        content.body = "Time for \(nextType.rawValue.lowercased())"
        let soundFile = (nextType == .rest) ? "doneit.mp3" : "bell.mp3";
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(seconds, 1)),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "interval-end",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
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
    
    // Anuluj WSZYSTKIE powiadomienia
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        print("🔔 All notifications cancelled")
    }
}
