import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
class PomodoroManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var session: PomodoroSession = .default
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var currentIntervalType: IntervalType = .study
    @Published var remainingSeconds: Int = 0
    @Published var currentInterval: Int = 1
    @Published var totalIntervals: Int = 0
    
    // Unique identifier for current session to track notifications
    private(set) var sessionId: UUID?
    
    private var timer: Timer?
    // Maintain separate players so one sound doesn't cut the other
    private var players: [String: AVAudioPlayer] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    var progress: Double {
        let total = currentIntervalType == .study
            ? studyDurationSeconds
            : restDurationSeconds
        guard total > 0 else { return 0 }
        return Double(total - remainingSeconds) / Double(total)
    }
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    // Store actual durations in seconds for precise timing
    private(set) var studyDurationSeconds: Int = 0
    private(set) var restDurationSeconds: Int = 0
    
    func start() {
        // Use minutes converted to seconds
        studyDurationSeconds = session.studyMinutes * 60
        restDurationSeconds = session.restMinutes * 60
        startInternal()
    }
    
    /// Start with exact seconds - useful for testing short intervals
    func startWithSeconds(studySeconds: Int, restSeconds: Int) {
        studyDurationSeconds = studySeconds
        restDurationSeconds = restSeconds
        startInternal()
    }
    
    private func startInternal() {
        // Generate new session ID to invalidate any old notifications
        sessionId = UUID()
        
        totalIntervals = session.totalIntervals
        currentInterval = 1
        currentIntervalType = .study
        remainingSeconds = studyDurationSeconds
        isRunning = true
        isPaused = false
        
        print("🚀 START SESSION")
        print("   Study: \(studyDurationSeconds)s (\(studyDurationSeconds/60)m \(studyDurationSeconds%60)s)")
        print("   Rest: \(restDurationSeconds)s (\(restDurationSeconds/60)m \(restDurationSeconds%60)s)")
        print("   Total study time: \(session.totalStudyMinutes) min")
        print("   Total intervals: \(totalIntervals)")
        print("   Study sessions: \(totalIntervals / 2)")
        print("   Initial remainingSeconds: \(remainingSeconds)")
        
        startTimer()
        // Note: Background task is now managed by PomodoroTimerApp during scene phase changes
        updateLiveActivity()
        scheduleIntervalNotification()
    }
    
    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
        NotificationService.shared.cancelAllNotifications()
    }
    
    func resume() {
        isPaused = false
        startTimer()
        scheduleIntervalNotification()
    }
    
    func stop() {
        let oldSessionId = sessionId
        sessionId = nil  // Clear session ID first to invalidate any pending notifications
        
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        currentInterval = 1
        currentIntervalType = .study
        endBackgroundTask()  // Clean up any lingering background task
        endLiveActivity()
        NotificationService.shared.cancelNotifications(forSession: oldSessionId)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private var isTransitioning: Bool = false
    
    private func tick() {
        if remainingSeconds <= 0 {
            // Clamp and transition only once
            remainingSeconds = 0
            if !isTransitioning {
                transitionToNextInterval()
            }
            return
        }
        remainingSeconds -= 1
        
        if remainingSeconds % 10 == 0 {
            updateLiveActivity()
        }
    }
    
    private func transitionToNextInterval() {
        // Prevent re-entrancy
        guard !isTransitioning else { return }
        isTransitioning = true
        
        defer { isTransitioning = false }
        
        let totalStudySessions = max(1, totalIntervals / 2)
        
        print("🔄 TRANSITION START")
        print("   From: \(currentIntervalType.rawValue)")
        print("   Session: \(currentInterval)/\(totalStudySessions)")
        print("   Study duration setting: \(session.studyMinutes) min")
        print("   Rest duration setting: \(session.restMinutes) min")
        
        if currentIntervalType == .study {
            // Just finished a study period
            playSound(named: "doneit")
            
            // Check if this was the last study session
            if currentInterval >= totalStudySessions {
                print("✅ Completed all \(totalStudySessions) study sessions")
                completeSession()
                return
            }
            
            // Move to rest
            print("   Calculated rest duration: \(restDurationSeconds)s")
            
            if restDurationSeconds > 0 {
                // Explicitly notify SwiftUI of changes
                objectWillChange.send()
                currentIntervalType = .rest
                remainingSeconds = restDurationSeconds
                print("☕ NOW: type=\(currentIntervalType.rawValue), remaining=\(remainingSeconds)s")
            } else {
                // Skip rest, go directly to next study
                objectWillChange.send()
                currentInterval += 1
                remainingSeconds = studyDurationSeconds
                print("⏭️ Skipped rest, NOW: type=\(currentIntervalType.rawValue), remaining=\(remainingSeconds)s")
            }
        } else {
            // Just finished a rest period
            playSound(named: "bell")
            
            // Move to next study
            objectWillChange.send()
            currentInterval += 1
            currentIntervalType = .study
            remainingSeconds = studyDurationSeconds
            print("📚 NOW: type=\(currentIntervalType.rawValue), remaining=\(remainingSeconds)s, interval=\(currentInterval)")
        }
        
        print("🔄 TRANSITION END: \(currentIntervalType.rawValue) \(remainingSeconds)s")
        
        updateLiveActivity()
        scheduleIntervalNotification()
    }    
    private func completeSession() {
        // Play completion sound (doneit feels appropriate for completion)
        playSound(named: "doneit")
        stop()
        NotificationService.shared.sendCompletionNotification()
    }
    
    private func playSound(named name: String) {
        // If this sound is already playing, let it finish to avoid cutting
        if let existing = players[name], existing.isPlaying {
            return
        }
        
        // Prepare (or reuse) a player for the requested sound
        do {
            if let existing = players[name] {
                existing.currentTime = 0
                existing.play()
                return
            }
            
            guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
                AudioServicesPlaySystemSound(1007)
                return
            }
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            players[name] = player
            player.play()
        } catch {
            AudioServicesPlaySystemSound(1007)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Clean up finished players so they can be recreated next time
        if let entry = players.first(where: { $0.value === player }) {
            players.removeValue(forKey: entry.key)
        }
    }
    
    func startBackgroundTask() {
        // Only start if not already active
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        print("🔄 Background task started")
    }
    
    func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
            print("🔄 Background task ended")
        }
    }
    
    private func scheduleIntervalNotification() {
        guard let sessionId = sessionId else { return }
        NotificationService.shared.scheduleIntervalEnd(
            seconds: remainingSeconds,
            intervalType: currentIntervalType,
            nextType: currentIntervalType.next,
            sessionId: sessionId
        )
    }
    
    private func updateLiveActivity() {
        LiveActivityService.shared.update(
            remainingSeconds: remainingSeconds,
            intervalType: currentIntervalType,
            currentInterval: currentInterval,
            totalIntervals: totalIntervals / 2
        )
    }
    
    private func endLiveActivity() {
        LiveActivityService.shared.end()
    }
    
    // MARK: - Notification tap support
    func forceTransitionFromNotificationIfNeeded() {
        // If we’re not running, ignore. If paused, resume into next interval.
        guard isRunning else { return }
        if remainingSeconds <= 1 {
            transitionToNextInterval()
        }
    }
}
