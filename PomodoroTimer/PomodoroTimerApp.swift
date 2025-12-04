import SwiftUI
import UserNotifications

@main
struct PomodoroTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var pomodoroManager = PomodoroManager()
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pomodoroManager)
                .onAppear {
                    // Provide manager to app delegate so it can react to notification taps
                    appDelegate.pomodoroManager = pomodoroManager
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .background {
                        if pomodoroManager.isRunning && !pomodoroManager.isPaused,
                           let sessionId = pomodoroManager.sessionId {
                            // Schedule notifications for ALL remaining intervals while in background
                            NotificationService.shared.scheduleAllRemainingNotifications(
                                currentRemainingSeconds: pomodoroManager.remainingSeconds,
                                currentIntervalType: pomodoroManager.currentIntervalType,
                                currentInterval: pomodoroManager.currentInterval,
                                totalStudySessions: pomodoroManager.totalIntervals / 2,
                                studyDurationSeconds: pomodoroManager.studyDurationSeconds,
                                restDurationSeconds: pomodoroManager.restDurationSeconds,
                                sessionId: sessionId
                            )
                        } else {
                            // Cancel any pending notifications if session is not active
                            NotificationService.shared.cancelNotifications(forSession: pomodoroManager.sessionId)
                        }
                    } else if newPhase == .active {
                        // When returning to foreground, cancel background notifications
                        // The in-app timer will take over and schedule single notifications as needed
                        if let sessionId = pomodoroManager.sessionId, pomodoroManager.isRunning {
                            // Cancel the batch of background notifications
                            var identifiersToRemove: [String] = []
                            for i in 0..<20 {
                                identifiersToRemove.append("interval-\(i)-\(sessionId.uuidString)")
                            }
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                            print("🔔 Cancelled background notifications, timer taking over")
                        }
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Weak to avoid retain cycle; will be set from SwiftUI App on appear
    weak var pomodoroManager: PomodoroManager?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            print("🔔 Notification permission granted: \(granted)")
        }
        return true
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Handle taps on delivered notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Do not force any timer transition here to avoid double-advance and wrong durations.
        completionHandler()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Note: This method is NOT reliably called on iOS when app is swiped away
        // but we try to cancel here as a best-effort cleanup
        NotificationService.shared.cancelAllNotifications()
    }
}
