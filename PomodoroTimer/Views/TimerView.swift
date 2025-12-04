import SwiftUI

struct TimerView: View {
    @EnvironmentObject var manager: PomodoroManager
    
    var backgroundColor: Color {
        manager.currentIntervalType == .study
            ? Color.red.opacity(0.85)
            : Color.green.opacity(0.85)
    }
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: manager.currentIntervalType)
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 8) {
                    Text(manager.currentIntervalType.rawValue)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Session \(manager.currentInterval) of \(manager.totalIntervals / 2)")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Timer circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: manager.progress)
                        .stroke(Color.white, style: StrokeStyle(
                            lineWidth: 20,
                            lineCap: .round
                        ))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: manager.progress)
                    
                    VStack(spacing: 8) {
                        Text(manager.formattedTime)
                            .font(.system(size: 80, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Image(systemName: manager.currentIntervalType == .study
                            ? "book.fill"
                            : "cup.and.saucer.fill"
                        )
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .frame(width: 320, height: 320)
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    Button(action: { manager.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        if manager.isPaused {
                            manager.resume()
                        } else {
                            manager.pause()
                        }
                    }) {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .font(.largeTitle)
                            .foregroundColor(backgroundColor)
                            .frame(width: 90, height: 90)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    
                    // Spacer button for symmetry
                    Color.clear
                        .frame(width: 70, height: 70)
                }
                .padding(.bottom, 60)
            }
            .padding(.top, 60)
        }
    }
}
