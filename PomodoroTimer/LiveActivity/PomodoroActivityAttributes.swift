import ActivityKit
import Foundation

struct PomodoroActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingSeconds: Int
        var intervalType: IntervalType
        var currentInterval: Int
        var totalIntervals: Int
        
        var formattedTime: String {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var sessionName: String
}

class LiveActivityService {
    static let shared = LiveActivityService()
    
    private var activity: Activity<PomodoroActivityAttributes>?
    
    private init() {}
    
    func start(
        remainingSeconds: Int,
        intervalType: IntervalType,
        currentInterval: Int,
        totalIntervals: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = PomodoroActivityAttributes(sessionName: "Pomodoro")
        let state = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            intervalType: intervalType,
            currentInterval: currentInterval,
            totalIntervals: totalIntervals
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Live Activity start failed: \(error)")
        }
    }
    
    func update(
        remainingSeconds: Int,
        intervalType: IntervalType,
        currentInterval: Int,
        totalIntervals: Int
    ) {
        let state = PomodoroActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            intervalType: intervalType,
            currentInterval: currentInterval,
            totalIntervals: totalIntervals
        )
        
        Task {
            if activity == nil {
                start(
                    remainingSeconds: remainingSeconds,
                    intervalType: intervalType,
                    currentInterval: currentInterval,
                    totalIntervals: totalIntervals
                )
            } else {
                await activity?.update(using: state)
            }
        }
    }
    
    func end() {
        Task {
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }
}
