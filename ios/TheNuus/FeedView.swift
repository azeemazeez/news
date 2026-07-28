import SwiftUI

@Observable
final class FeedModel {
    enum State: Equatable {
        case loading
        case loaded(Edition)
        case failed(String)
    }

    private(set) var state: State = .loading

    /// True when what's on screen came from disk rather than the network.
    private(set) var isStale = false

    func load() async {
        do {
            let edition = try await NewsService.shared.latestEdition()
            state = .loaded(edition)
            isStale = false
        } catch {
            // Fall back to the last edition we successfully fetched.
            if let cached = NewsService.shared.cachedEdition() {
                state = .loaded(cached)
                isStale = true
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }
}

struct FeedView: View {
    let model: FeedModel

    @State private var selectedArticle: URL?

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView().tint(Theme.purple)

                case .loaded(let edition):
                    storyList(edition)

                case .failed(let message):
                    failureView(message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("The Nuus")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.purple)
        .sheet(item: $selectedArticle) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    // MARK: - Subviews

    private func storyList(_ edition: Edition) -> some View {
        List {
            Section {
                ForEach(edition.stories) { story in
                    Button {
                        selectedArticle = story.articleURL
                    } label: {
                        StoryRow(story: story)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Theme.rule)
                }
            } header: {
                header(for: edition)
            }
        }
        .listStyle(.plain)
        .refreshable { await model.load() }
    }

    private func header(for edition: Edition) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(edition.displayDate.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Theme.secondary)

            if model.isStale {
                Text("Showing the last saved edition — pull to refresh.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary.opacity(0.8))
            }
        }
        .padding(.vertical, 6)
        .textCase(nil)
    }

    private func failureView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text("Couldn't load today's edition")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                Task { await model.load() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Theme.purple, in: Capsule())
        }
        .padding(32)
    }
}

struct StoryRow: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                Text(story.cleanIntro).fontWeight(.semibold)
                    + Text(" ")
                    + Text(story.cleanBody)
                    + Text(" ")
                    + Text(story.cleanLinkText)
                        .foregroundColor(Theme.purple)
                        .underline()
            }
            .font(.system(size: 16))
            .foregroundStyle(Theme.text)
            .lineSpacing(3)

            Text(story.source)
                .font(.system(size: 11, weight: .medium))
                .kerning(0.4)
                .foregroundStyle(Theme.purple)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// Lets a bare URL drive a `.sheet(item:)`.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
