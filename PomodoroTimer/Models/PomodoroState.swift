import Foundation

enum IntervalType: String, Codable {
    case study = "Study"
    case rest = "Rest"
    
    var next: IntervalType {
        self == .study ? .rest : .study
    }
}

struct PomodoroSession {
    var studyMinutes: Int
    var restMinutes: Int
    var totalStudyMinutes: Int
    
    var totalIntervals: Int {
        let cycleLength = studyMinutes + restMinutes
        guard cycleLength > 0 else { return 0 }
        return (totalStudyMinutes / studyMinutes) * 2
    }
    
    static let `default` = PomodoroSession(
        studyMinutes: 25,
        restMinutes: 5,
        totalStudyMinutes: 240
    )
}
