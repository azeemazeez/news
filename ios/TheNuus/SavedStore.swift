import Foundation
import Observation

/// Stories the reader bookmarked, kept on disk so they survive relaunches
/// and stay readable offline.
@Observable
final class SavedStore {
    static let shared = SavedStore()

    private(set) var stories: [Story] = []

    private let fileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "saved-stories.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let stories = try? JSONDecoder().decode([Story].self, from: data) {
            self.stories = stories
        }
    }

    func isSaved(_ story: Story) -> Bool {
        stories.contains { $0.id == story.id }
    }

    func toggle(_ story: Story) {
        if let index = stories.firstIndex(where: { $0.id == story.id }) {
            stories.remove(at: index)
        } else {
            stories.insert(story, at: 0)
        }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        stories.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stories) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
