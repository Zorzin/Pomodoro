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
                        if !pomodoroManager.isRunning {
                            NotificationService.shared.cancelAllNotifications()
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
        NotificationService.shared.cancelAllNotifications()
    }
}
