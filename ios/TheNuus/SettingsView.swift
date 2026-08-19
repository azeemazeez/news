import AVFoundation
import SwiftUI

struct SettingsView: View {
    @State private var reminderOn = NotificationManager.shared.isEnabled
    @State private var permissionDenied = false

    var body: some View {
        Form {
                Section {
                    MastheadBlock()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Reading") {
                    Picker("Text size", selection: Bindable(Prefs.shared).textSize) {
                        ForEach(Prefs.TextSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Listening") {
                    NavigationLink {
                        VoicePickerView()
                    } label: {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(currentVoiceName)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderOn)
                        .onChange(of: reminderOn) { _, on in
                            Task {
                                let ok = await NotificationManager.shared.setEnabled(on)
                                if on && !ok {
                                    reminderOn = false
                                    permissionDenied = true
                                }
                            }
                        }

                    if reminderOn {
                        DatePicker(
                            "Time",
                            selection: Bindable(NotificationManager.shared).reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } footer: {
                    if permissionDenied {
                        Text("Notifications are turned off for The Nuus. Enable them in Settings to get the daily reminder.")
                    } else {
                        Text("A quiet nudge each day when the new edition is ready.")
                    }
                }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentVoiceName: String {
        if Prefs.shared.voiceIdentifier == nil { return "Automatic" }
        return SpeechController.currentVoice()?.name ?? "Automatic"
    }
}

/// Lists the installed English voices with a tap-to-preview, so listeners
/// can pick the narrator they like.
struct VoicePickerView: View {
    @State private var preview = SpeechController()

    // The novelty and legacy robotic voices Apple ships alongside the real
    // ones; quality metadata doesn't reliably separate them, so exclude by name.
    private static let syntheticNames: Set<String> = [
        "albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos",
        "deranged", "wobble", "good news", "jester", "organ", "superstar",
        "trinoids", "whisper", "zarvox", "fred", "junior", "kathy", "ralph",
        "eddy", "flo", "grandma", "grandpa", "reed", "rocko", "sandy", "shelley",
    ]

    private let voices = SpeechController.englishVoices()
        .filter { !Self.syntheticNames.contains($0.name.lowercased()) }
        .sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return ($0.name, $0.language) < ($1.name, $1.language)
        }

    var body: some View {
        List {
            Section {
                row(name: "Automatic", detail: "Best installed voice", isSelected: Prefs.shared.voiceIdentifier == nil) {
                    Prefs.shared.voiceIdentifier = nil
                    speakSample(with: SpeechController.bestAvailableVoice())
                }
            } footer: {
                Text("Tap a voice to hear it. More voices can be downloaded in the iOS Settings app under Accessibility, Spoken Content, Voices.")
            }

            if voices.isEmpty {
                Section {
                    Text("No natural-sounding voices are installed on this device yet. Download one in the iOS Settings app under Accessibility, Spoken Content, Voices, English — then it will appear here.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                }
            } else {
                Section {
                    ForEach(voices, id: \.identifier) { voice in
                        row(
                            name: voice.name,
                            detail: detailLabel(for: voice),
                            isSelected: Prefs.shared.voiceIdentifier == voice.identifier
                        ) {
                            Prefs.shared.voiceIdentifier = voice.identifier
                            speakSample(with: voice)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
    }

    private func row(name: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .foregroundStyle(Theme.text)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.purple)
                }
            }
        }
    }

    private func detailLabel(for voice: AVSpeechSynthesisVoice) -> String {
        let region = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        switch voice.quality {
        case .premium: return "\(region) · Premium"
        case .enhanced: return "\(region) · Enhanced"
        default: return region
        }
    }

    private func speakSample(with voice: AVSpeechSynthesisVoice?) {
        preview.stop()
        preview.speakPreview("The Nuus. Serving you bite-sized news, every day.", voice: voice)
    }
}
