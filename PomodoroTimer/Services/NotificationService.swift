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
    
    /// Schedule notifications for all remaining intervals when app goes to background.
    /// This ensures users get notified even when the app is suspended.
    func scheduleAllRemainingNotifications(
        currentRemainingSeconds: Int,
        currentIntervalType: IntervalType,
        currentInterval: Int,
        totalStudySessions: Int,
        studyDurationSeconds: Int,
        restDurationSeconds: Int,
        sessionId: UUID
    ) {
        // Cancel any existing notifications for this session
        let existingIdentifier = "interval-end-\(sessionId.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [existingIdentifier])
        
        // Also cancel any numbered notifications from previous background sessions
        var identifiersToRemove: [String] = []
        for i in 0..<20 {
            identifiersToRemove.append("interval-\(i)-\(sessionId.uuidString)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        
        currentSessionId = sessionId
        
        var timeOffset = 0
        var intervalType = currentIntervalType
        var interval = currentInterval
        var notificationIndex = 0
        
        // Start with remaining time in current interval
        timeOffset = currentRemainingSeconds
        
        print("🔔 Scheduling background notifications:")
        print("   Starting: \(intervalType.rawValue), interval \(interval)/\(totalStudySessions)")
        print("   First notification in \(timeOffset)s")
        
        // Schedule notifications for upcoming intervals (limit to avoid too many)
        // We'll schedule up to 10 notifications or until session would complete
        while notificationIndex < 10 {
            // Schedule notification for end of current interval
            let nextType = intervalType.next
            
            // Check if session would be complete
            if intervalType == .study && interval >= totalStudySessions {
                // This is the last study session - schedule completion notification
                scheduleNotificationAt(
                    seconds: timeOffset,
                    title: "🎉 Session Complete!",
                    body: "Great work! You've completed your study session.",
                    soundFile: "doneit.mp3",
                    identifier: "interval-\(notificationIndex)-\(sessionId.uuidString)",
                    sessionId: sessionId
                )
                print("   [\(notificationIndex)] Completion at \(timeOffset)s")
                break
            }
            
            // Schedule interval end notification
            let title = "\(intervalType.rawValue) Complete!"
            let body = "Time for \(nextType.rawValue.lowercased())"
            let soundFile = (nextType == .rest) ? "doneit.mp3" : "bell.mp3"
            
            scheduleNotificationAt(
                seconds: timeOffset,
                title: title,
                body: body,
                soundFile: soundFile,
                identifier: "interval-\(notificationIndex)-\(sessionId.uuidString)",
                sessionId: sessionId
            )
            print("   [\(notificationIndex)] \(intervalType.rawValue) end at \(timeOffset)s")
            
            notificationIndex += 1
            
            // Move to next interval
            if intervalType == .study {
                intervalType = .rest
                if restDurationSeconds > 0 {
                    timeOffset += restDurationSeconds
                } else {
                    // Skip rest if duration is 0
                    interval += 1
                    intervalType = .study
                    timeOffset += studyDurationSeconds
                }
            } else {
                interval += 1
                intervalType = .study
                timeOffset += studyDurationSeconds
            }
        }
        
        print("🔔 Scheduled \(notificationIndex) background notifications")
    }
    
    private func scheduleNotificationAt(
        seconds: Int,
        title: String,
        body: String,
        soundFile: String,
        identifier: String,
        sessionId: UUID
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundFile))
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["sessionId": sessionId.uuidString]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(seconds, 1)),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 Failed to schedule notification \(identifier): \(error)")
            }
        }
    }
}
