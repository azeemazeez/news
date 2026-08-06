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
        if isSpeaking {
            if isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
            } else {
                synthesizer.pauseSpeaking(at: .word)
                isPaused = true
            }
            return
        }

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)

        speak("The Nuus. \(edition.displayDate).")
        for story in edition.stories {
            speak("\(story.cleanIntro). \(story.cleanBody)")
        }
        isSpeaking = true
        isPaused = false
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.postUtteranceDelay = 0.4
        synthesizer.speak(utterance)
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
