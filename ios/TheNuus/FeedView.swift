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

    /// Set when the user picked a past edition from the archive.
    private(set) var pastEditionDate: String?

    func load() async {
        do {
            let edition = try await NewsService.shared.latestEdition()
            state = .loaded(edition)
            isStale = false
            pastEditionDate = nil
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

    func load(date: String) async {
        do {
            let edition = try await NewsService.shared.edition(for: date)
            state = .loaded(edition)
            isStale = false
            pastEditionDate = date
        } catch {
            // Keep whatever is on screen; a failed archive tap shouldn't blank the feed.
        }
    }
}

struct FeedView: View {
    let model: FeedModel

    @State private var selectedArticle: URL?
    @State private var menuScreen: MenuScreen?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SiteHeaderView()

                switch model.state {
                case .loading:
                    ProgressView()
                        .tint(Theme.purple)
                        .padding(.top, 80)

                case .loaded(let edition):
                    stories(edition)

                case .failed(let message):
                    failureView(message)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .refreshable { await model.load() }
        .overlay(alignment: .topLeading) {
            Menu {
                Button {
                    menuScreen = .archive
                } label: {
                    Label("Archive", systemImage: "calendar")
                }
                Button {
                    menuScreen = .about
                } label: {
                    Label("About", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .padding(.leading, 4)
            // Attached here, not on the ScrollView: two sheet modifiers on
            // one view conflict, and the article sheet already lives there.
            .sheet(item: $menuScreen) { screen in
                switch screen {
                case .archive:
                    ArchiveView { date in
                        menuScreen = nil
                        Task { await model.load(date: date) }
                    }
                case .about:
                    AboutView()
                }
            }
        }
        .sheet(item: $selectedArticle) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }

    // MARK: - Subviews

    private func stories(_ edition: Edition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.isStale {
                Text("Showing the last saved edition — pull to refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            } else if let date = model.pastEditionDate {
                Text("Edition from \(ArchiveView.dayLabel(for: date)) — pull to refresh for today.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }

            ForEach(edition.stories) { story in
                Button {
                    selectedArticle = story.articleURL
                } label: {
                    StoryRow(story: story)
                }
                .buttonStyle(.plain)

                if story.id != edition.stories.last?.id {
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
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
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

// Lets a bare URL drive a `.sheet(item:)`.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
