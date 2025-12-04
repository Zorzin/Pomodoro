import SwiftUI

struct SetupView: View {
    @EnvironmentObject var manager: PomodoroManager
    
    @State private var studyMinutes: Double = 25
    @State private var restMinutes: Double = 5
    @State private var totalHours: Double = 4
    
    var totalSessions: Int {
        let studyInt = Int(studyMinutes)
        guard studyInt > 0 else { return 0 }
        return Int(totalHours * 60) / studyInt
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
                        Text("\(Int(studyMinutes)) min")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    Slider(value: $studyMinutes, in: 1...60, step: 5)
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
                Text("(\(totalSessions) × \(Int(studyMinutes))min study + \(Int(restMinutes))min rest)")
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
    }
    
    private func startSession() {
        manager.session = PomodoroSession(
            studyMinutes: Int(studyMinutes),
            restMinutes: Int(restMinutes),
            totalStudyMinutes: Int(totalHours * 60)
        )
        manager.start()
    }
}
