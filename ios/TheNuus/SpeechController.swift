import AVFoundation
import Observation

/// Reads an edition aloud with on-device text-to-speech.
@Observable
final class SpeechController: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

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
        speak("The Nuus. \(edition.displayDate).")
        for story in edition.stories {
            speak(Self.spokenText(for: story))
        }
        isSpeaking = true
        isPaused = false
    }

    /// Starts reading a single story, or toggles pause if already reading.
    func toggle(_ story: Story) {
        if togglePauseIfSpeaking() { return }

        beginSession()
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
        return true
    }

    private func beginSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
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

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.postUtteranceDelay = 0.4
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
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking {
            isSpeaking = false
            isPaused = false
        }
    }
}
