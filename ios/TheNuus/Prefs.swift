import Foundation
import Observation
import SwiftUI

/// User-adjustable reading preferences, persisted in UserDefaults.
@Observable
final class Prefs {
    static let shared = Prefs()

    enum TextSize: String, CaseIterable, Identifiable {
        case small = "Small"
        case regular = "Regular"
        case large = "Large"

        var id: String { rawValue }

        var scale: CGFloat {
            switch self {
            case .small: 0.9
            case .regular: 1.0
            case .large: 1.18
            }
        }
    }

    var textSize: TextSize {
        didSet { UserDefaults.standard.set(textSize.rawValue, forKey: "textSize") }
    }

    /// Identifier of the chosen text-to-speech voice; nil means "pick the
    /// best installed voice automatically".
    var voiceIdentifier: String? {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: "voiceIdentifier") }
    }

    /// IDs of stories the user has opened, newest last, so the feed can show
    /// what's already been read. Capped so the list doesn't grow forever.
    private(set) var readStoryIDs: [String]

    private init() {
        textSize = TextSize(rawValue: UserDefaults.standard.string(forKey: "textSize") ?? "") ?? .regular
        voiceIdentifier = UserDefaults.standard.string(forKey: "voiceIdentifier")
        readStoryIDs = UserDefaults.standard.stringArray(forKey: "readStories") ?? []
    }

    func markRead(_ story: Story) {
        guard !readStoryIDs.contains(story.id) else { return }
        readStoryIDs.append(story.id)
        readStoryIDs = Array(readStoryIDs.suffix(500))
        UserDefaults.standard.set(readStoryIDs, forKey: "readStories")
    }

    func isRead(_ story: Story) -> Bool { readStoryIDs.contains(story.id) }
}
