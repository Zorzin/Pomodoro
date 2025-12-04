import SwiftUI

struct SetupView: View {
    @EnvironmentObject var manager: PomodoroManager
    
    // Study time in seconds for fine-grained control during testing
    @State private var studySeconds: Double = 25 * 60  // 25 minutes default
    @State private var restMinutes: Double = 5
    @State private var totalHours: Double = 4
    
    // Ensure values are valid when view appears
    private func validateValues() {
        if studySeconds < 15 { studySeconds = 15 }
        if restMinutes < 1 { restMinutes = 1 }
        if totalHours < 0.5 { totalHours = 0.5 }
    }
    
    // Convert study seconds to minutes for calculations
    private var studyMinutes: Double {
        studySeconds / 60.0
    }
    
    var totalSessions: Int {
        let studyMins = studyMinutes
        guard studyMins > 0 else { return 0 }
        return Int(totalHours * 60 / studyMins)
    }
    
    // Format study time display (show seconds if under 1 minute)
    private var studyTimeFormatted: String {
        let seconds = Int(studySeconds)
        if seconds < 60 {
            return "\(seconds) sec"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) min"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        }
    }
    
    private var totalHoursFormatted: String {
        // Display minutes when below 1 hour, and use .5 granularity otherwise.
        let minutes = Int(totalHours * 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let wholeHours = Int(totalHours)
        let hasHalf = abs(totalHours - Double(wholeHours) - 0.5) < 0.0001
        if hasHalf {
            // Show e.g. "1.5 h"
            return "\(wholeHours).5 h"
        } else {
            // Show e.g. "2 h"
            return "\(wholeHours) h"
        }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Text("Pomodoro Timer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 30) {
                // Study interval
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.red)
                        Text("Study Interval")
                            .font(.headline)
                        Spacer()
                        Text(studyTimeFormatted)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    // Allow 15 seconds to 60 minutes (3600 seconds)
                    // Step: 15 seconds for values under 1 min, then 60 seconds (1 min) steps
                    Slider(value: $studySeconds, in: 15...3600, step: 15)
                        .tint(.red)
                }
                
                // Rest interval
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(.green)
                        Text("Rest Interval")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(restMinutes)) min")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Slider(value: $restMinutes, in: 1...30, step: 1)
                        .tint(.green)
                }
                
                // Total time
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("Total Study Time")
                            .font(.headline)
                        Spacer()
                        Text(totalHoursFormatted)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Slider(value: $totalHours, in: 0.5...8, step: 0.5)
                        .tint(.blue)
                }
            }
            .padding(.horizontal, 40)
            
            // Summary
            VStack(spacing: 8) {
                Text("Session Summary")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("\(totalSessions) study sessions")
                    .font(.title2)
                Text("(\(totalSessions) × \(studyTimeFormatted) study + \(Int(restMinutes))min rest)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Spacer()
            
            Button(action: startSession) {
                Label("Start Session", systemImage: "play.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding(.top, 60)
        .onAppear {
            validateValues()
        }
    }
    
    private func startSession() {
        // Convert study seconds to minutes for the session
        // Use ceiling to ensure at least 1 minute if seconds > 0
        let studyMins = max(1, Int(ceil(studySeconds / 60.0)))
        manager.session = PomodoroSession(
            studyMinutes: studyMins,
            restMinutes: Int(restMinutes),
            totalStudyMinutes: Int(totalHours * 60)
        )
        // Override with exact seconds for testing short intervals
        manager.startWithSeconds(studySeconds: Int(studySeconds), restSeconds: Int(restMinutes) * 60)
    }
}
