import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: PomodoroManager
    
    var body: some View {
        Group {
            if manager.isRunning {
                TimerView()
            } else {
                SetupView()
            }
        }
        .animation(.easeInOut, value: manager.isRunning)
    }
}

#Preview {
    ContentView()
        .environmentObject(PomodoroManager())
}
