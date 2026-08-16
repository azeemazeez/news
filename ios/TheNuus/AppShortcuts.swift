import AppIntents
import Observation

/// Cross-cutting requests raised by App Intents and handled by the UI once
/// the app is frontmost and the edition has loaded.
@Observable
final class AppActions {
    static let shared = AppActions()
    private init() {}

    /// Set by ListenEditionIntent; FeedView starts playback and clears it.
    var listenRequested = false
}

struct ReadEditionIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Today's Edition"
    static let description = IntentDescription("Opens The Nuus to today's edition.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct ListenEditionIntent: AppIntent {
    static let title: LocalizedStringResource = "Listen to Today's Edition"
    static let description = IntentDescription("Opens The Nuus and reads today's edition aloud.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppActions.shared.listenRequested = true
        return .result()
    }
}

struct TheNuusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadEditionIntent(),
            phrases: [
                "Read today's \(.applicationName)",
                "Open today's \(.applicationName) edition",
            ],
            shortTitle: "Read Today's Edition",
            systemImageName: "newspaper"
        )
        AppShortcut(
            intent: ListenEditionIntent(),
            phrases: [
                "Listen to \(.applicationName)",
                "Play today's \(.applicationName) edition",
            ],
            shortTitle: "Listen to Today's Edition",
            systemImageName: "play.circle"
        )
    }
}
