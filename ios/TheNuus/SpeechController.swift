import AVFoundation
import MediaPlayer
import Observation

/// Reads an edition aloud with on-device text-to-speech.
@Observable
final class SpeechController: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var remoteCommandTokens: [Any] = []

    private(set) var isSpeaking = false
    private(set) var isPaused = false

    /// True while audio is actually playing (speaking and not paused).
    var isPlaying: Bool { isSpeaking && !isPaused }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Starts reading the edition, or toggles pause if already reading.
    func toggle(_ edition: Edition) {
        if togglePauseIfSpeaking() { return }

        beginSession()
        startNowPlaying(title: "The Nuus — \(edition.displayDate)")
        speak("The Nuus. \(edition.displayDate).")
        for story in edition.stories {
            speak(Self.spokenText(for: story), pauseAfter: 2.0)
        }
        speak("That's all the news for today, tune in tomorrow for more news.")
        isSpeaking = true
        isPaused = false
    }

    /// Starts reading a single story, or toggles pause if already reading.
    func toggle(_ story: Story) {
        if togglePauseIfSpeaking() { return }

        beginSession()
        startNowPlaying(title: story.cleanIntro)
        speak(Self.spokenText(for: story))
        isSpeaking = true
        isPaused = false
    }

    /// The full story text: the link text is the tail of the closing
    /// sentence, so leaving it out would cut every story off mid-thought.
    private static func spokenText(for story: Story) -> String {
        "\(story.cleanIntro). \(story.cleanBody) \(story.cleanLinkText)"
    }

    private func togglePauseIfSpeaking() -> Bool {
        guard isSpeaking else { return false }
        if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        } else {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        }
        updateNowPlayingRate()
        return true
    }

    // MARK: - Lock screen / background playback

    /// Publishes what's playing to the lock screen and hooks up its
    /// play/pause controls, so listening survives backgrounding.
    private func startNowPlaying(title: String) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "The Nuus",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]

        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)

        remoteCommandTokens = [
            center.playCommand.addTarget { [weak self] _ in
                guard let self, self.isSpeaking, self.isPaused else { return .commandFailed }
                self.synthesizer.continueSpeaking()
                self.isPaused = false
                self.updateNowPlayingRate()
                return .success
            },
            center.pauseCommand.addTarget { [weak self] _ in
                guard let self, self.isSpeaking, !self.isPaused else { return .commandFailed }
                self.synthesizer.pauseSpeaking(at: .word)
                self.isPaused = true
                self.updateNowPlayingRate()
                return .success
            },
            center.togglePlayPauseCommand.addTarget { [weak self] _ in
                guard let self, self.isSpeaking else { return .commandFailed }
                _ = self.togglePauseIfSpeaking()
                return .success
            },
        ]
    }

    private func updateNowPlayingRate() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] =
            isPlaying ? 1.0 : 0.0
    }

    private func endNowPlaying() {
        guard !remoteCommandTokens.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        remoteCommandTokens = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func beginSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        endNowPlaying()
    }

    /// Speaks a short sample with an explicit voice (used by the voice picker).
    func speakPreview(_ text: String, voice: AVSpeechSynthesisVoice?) {
        stop()
        beginSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        synthesizer.speak(utterance)
        isSpeaking = true
        isPaused = false
    }

    private func speak(_ text: String, pauseAfter: TimeInterval = 0.4) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.postUtteranceDelay = pauseAfter
        utterance.voice = Self.currentVoice()
        synthesizer.speak(utterance)
    }

    // MARK: - Voice selection

    /// The user's chosen voice, or the best installed English voice.
    static func currentVoice() -> AVSpeechSynthesisVoice? {
        if let id = Prefs.shared.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            return voice
        }
        return bestAvailableVoice()
    }

    /// Highest-quality installed English voice: premium beats enhanced beats
    /// compact, and the device's own English variant beats other accents.
    static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let preferred = AVSpeechSynthesisVoice.currentLanguageCode()
        return englishVoices().max { score($0, preferred: preferred) < score($1, preferred: preferred) }
    }

    static func englishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
    }

    private static func score(_ voice: AVSpeechSynthesisVoice, preferred: String) -> Int {
        var score: Int
        switch voice.quality {
        case .premium: score = 100
        case .enhanced: score = 50
        default: score = 0
        }
        if voice.language == preferred { score += 20 }
        else if voice.language == "en-US" { score += 10 }
        return score
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking {
            isSpeaking = false
            isPaused = false
            endNowPlaying()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking {
            isSpeaking = false
            isPaused = false
            endNowPlaying()
        }
    }
}
