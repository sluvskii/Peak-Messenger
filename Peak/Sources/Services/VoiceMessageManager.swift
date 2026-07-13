import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class VoiceMessageManager: NSObject {
    static let shared = VoiceMessageManager()
    
    // Recording state
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var audioLevels: [Float] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var recordTimer: Timer?
    private var tempRecordURL: URL?
    
    // Playback state
    var isPlaying = false
    var playingMessageId: UUID? = nil
    var playProgress: Double = 0.0
    var playDuration: TimeInterval = 0
    var playCurrentTime: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var playTimer: Timer?
    
    override private init() {
        super.init()
    }
    
    // MARK: - Recording
    
    func startRecording() async {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            // Check microphone permission without async delay if already granted
            let permission = session.recordPermission
            if permission == .undetermined {
                let granted = await withCheckedContinuation { continuation in
                    session.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                guard granted else { return }
            } else if permission == .denied {
                print("Microphone access denied")
                return
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
            self.tempRecordURL = fileURL
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            
            if recorder.record() {
                self.audioRecorder = recorder
                self.isRecording = true
                self.recordingDuration = 0
                self.audioLevels = Array(repeating: 0.1, count: 30)
                
                // Start timer to track duration and levels
                self.recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.updateRecordingProgress()
                    }
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func updateRecordingProgress() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recordingDuration = recorder.currentTime
        
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        // Convert dB to linear value [0.0, 1.0]
        let level = max(0.02, pow(10, power / 20) * 1.5)
        
        audioLevels.removeFirst()
        audioLevels.append(min(1.0, level))
    }
    
    func stopRecording() -> (url: URL, duration: Double)? {
        guard isRecording, let recorder = audioRecorder else { return nil }
        
        recorder.stop()
        recordTimer?.invalidate()
        recordTimer = nil
        isRecording = false
        
        let url = recorder.url
        let duration = recordingDuration
        
        audioRecorder = nil
        
        // Deactivate session briefly to clean up
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        return (url, duration)
    }
    
    func cancelRecording() {
        guard isRecording, let recorder = audioRecorder else { return }
        
        recorder.stop()
        recorder.deleteRecording()
        
        recordTimer?.invalidate()
        recordTimer = nil
        isRecording = false
        audioRecorder = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // MARK: - Playback
    
    func playVoiceMessage(url: URL, messageId: UUID) {
        // If already playing this message, pause it
        if playingMessageId == messageId && isPlaying {
            pause()
            return
        }
        
        // If paused on this message, resume it
        if playingMessageId == messageId && !isPlaying, let player = audioPlayer {
            player.play()
            isPlaying = true
            startPlaybackTimer()
            return
        }
        
        // Otherwise stop whatever is playing and play new message
        stopPlayback()
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            
            // Try downloading url locally if it's a remote URL, or playing direct if local file
            let player: AVAudioPlayer
            if url.isFileURL {
                player = try AVAudioPlayer(contentsOf: url)
            } else {
                // If it is remote, load data first
                // For a premium feel, let's load it asynchronously or use a cache
                // We'll cache the downloaded audio files to avoid reloading
                let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: cacheURL.path) {
                    player = try AVAudioPlayer(contentsOf: cacheURL)
                } else {
                    Task.detached {
                        do {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            try data.write(to: cacheURL, options: .atomic)
                            await MainActor.run {
                                self.playVoiceMessage(url: cacheURL, messageId: messageId)
                            }
                        } catch {
                            print("Failed to download voice message data: \(error)")
                        }
                    }
                    return
                }
            }
            
            player.delegate = self
            player.prepareToPlay()
            if player.play() {
                self.audioPlayer = player
                self.playingMessageId = messageId
                self.isPlaying = true
                self.playDuration = player.duration
                self.playCurrentTime = 0
                self.playProgress = 0.0
                
                startPlaybackTimer()
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }
    
    func pause() {
        guard isPlaying, let player = audioPlayer else { return }
        player.pause()
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playTimer?.invalidate()
        playTimer = nil
        isPlaying = false
        playingMessageId = nil
        playProgress = 0.0
        playCurrentTime = 0
    }
    
    func seek(to progress: Double) {
        guard let player = audioPlayer else { return }
        let time = progress * player.duration
        player.currentTime = time
        playCurrentTime = time
        playProgress = progress
    }
    
    private func startPlaybackTimer() {
        playTimer?.invalidate()
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackProgress()
            }
        }
    }
    
    private func updatePlaybackProgress() {
        guard let player = audioPlayer, player.isPlaying else { return }
        playCurrentTime = player.currentTime
        playProgress = player.duration > 0 ? (player.currentTime / player.duration) : 0
    }
}

// MARK: - AVAudioRecorderDelegate
extension VoiceMessageManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Handled in stopRecording
    }
}

// MARK: - AVAudioPlayerDelegate
extension VoiceMessageManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopPlayback()
        }
    }
}
