import ActivityKit
import WidgetKit
import SwiftUI

struct PomodoroWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomodoroActivityAttributes.self) { context in
            let isStudy = context.state.intervalType == IntervalType.study
            let icon = isStudy ? "📚" : "☕"
            HStack {
                Text(icon)
                    .font(.largeTitle)
                Text(context.state.formattedTime)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Text(isStudy ? "Study" : "Rest")
            }
            .padding()
            .background(isStudy ? Color.red.opacity(0.3) : Color.green.opacity(0.3))
            
        } dynamicIsland: { context in
            let isStudy = context.state.intervalType == IntervalType.study
            let icon = isStudy ? "📚" : "☕"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 8) {
                        Text(icon)
                        Text(context.state.formattedTime)
                            .font(.title)
                    }
                }
            } compactLeading: {
                Text(icon)
            } compactTrailing: {
                Text(context.state.formattedTime)
                    .font(.caption)
            } minimal: {
                Text(icon)
            }
        }
    }
}
