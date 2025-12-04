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
    
    private var timer: Timer?
    // Maintain separate players so one sound doesn't cut the other
    private var players: [String: AVAudioPlayer] = [:]
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    var progress: Double {
        let total = currentIntervalType == .study
            ? session.studyMinutes * 60
            : session.restMinutes * 60
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
    
    func start() {
        totalIntervals = session.totalIntervals
        currentInterval = 1
        currentIntervalType = .study
        remainingSeconds = session.studyMinutes * 60
        isRunning = true
        isPaused = false
        
        startTimer()
        startBackgroundTask()
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
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        remainingSeconds = 0
        currentInterval = 1
        endBackgroundTask()
        endLiveActivity()
        NotificationService.shared.cancelAllNotifications()
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
        // Prevent re-entrancy if called from multiple sources (timer, notification, app state changes)
        guard !isTransitioning else { return }
        isTransitioning = true
        
        // Determine next type to play the right sound
        let nextType = currentIntervalType.next
        let soundName = (nextType == .rest) ? "doneit" : "bell" 
        playSound(named: soundName)
        
        if currentIntervalType == .rest {
            currentInterval += 1
        }
        
        if currentInterval > totalIntervals / 2 && currentIntervalType == .rest {
            isTransitioning = false
            completeSession()
            return
        }
        
        currentIntervalType = nextType
        // Always set full duration for the next interval
        let duration = currentIntervalType == .study
            ? session.studyMinutes * 60
            : session.restMinutes * 60
        
        // If duration is 0, skip this interval and move to next
        if duration <= 0 {
            isTransitioning = false
            transitionToNextInterval()
            return
        }
        
        remainingSeconds = duration
        
        updateLiveActivity()
        scheduleIntervalNotification()
        // Removed immediate 'interval-change' notification to avoid duplicate alerts.
        
        isTransitioning = false
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
    
    private func startBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func scheduleIntervalNotification() {
        NotificationService.shared.scheduleIntervalEnd(
            seconds: remainingSeconds,
            intervalType: currentIntervalType,
            nextType: currentIntervalType.next
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
