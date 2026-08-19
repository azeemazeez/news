import Foundation
import Observation

/// A bookmarked story plus the edition it came from.
struct SavedItem: Codable, Equatable, Hashable, Identifiable {
    let story: Story
    let editionDate: String?

    var id: String { story.id }
}

/// Stories the reader bookmarked, kept on disk so they survive relaunches
/// and stay readable offline.
@Observable
final class SavedStore {
    static let shared = SavedStore()

    private(set) var items: [SavedItem] = []

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "saved-stories.json")
    }()

    private init() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let items = try? JSONDecoder().decode([SavedItem].self, from: data) {
            self.items = items
        } else if let stories = try? JSONDecoder().decode([Story].self, from: data) {
            // Saved before edition dates were recorded.
            items = stories.map { SavedItem(story: $0, editionDate: nil) }
        }
    }

    func isSaved(_ story: Story) -> Bool {
        items.contains { $0.id == story.id }
    }

    func toggle(_ story: Story, editionDate: String?) {
        if let index = items.firstIndex(where: { $0.id == story.id }) {
            items.remove(at: index)
        } else {
            items.insert(SavedItem(story: story, editionDate: editionDate), at: 0)
        }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
