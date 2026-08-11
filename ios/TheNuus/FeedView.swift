import PostHog
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
            PostHogSDK.shared.capture("edition_loaded", properties: ["edition": "latest"])
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
            PostHogSDK.shared.capture("edition_loaded", properties: ["edition": "archive", "date": date])
        } catch {
            // Keep whatever is on screen; a failed archive tap shouldn't blank the feed.
        }
    }
}

struct FeedView: View {
    let model: FeedModel

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedStory: Story?
    @State private var menuScreen: MenuScreen?
    @State private var speech = SpeechController()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SiteHeaderView { screen in
                    menuScreen = screen
                }
                .sheet(item: $menuScreen) { screen in
                    switch screen {
                    case .archive:
                        ArchiveView { date in
                            menuScreen = nil
                            speech.stop()
                            Task { await model.load(date: date) }
                        }
                    case .saved:
                        SavedView()
                    case .settings:
                        SettingsView()
                    case .about:
                        AboutView()
                    }
                }

                switch model.state {
                case .loading:
                    ProgressView()
                        .tint(Theme.purple)
                        .padding(.top, 80)

                case .loaded(let edition):
                    stories(edition)
                        .containerRelativeFrame(.horizontal) { width, _ in
                            sizeClass == .regular ? width * 0.75 : width
                        }

                case .failed(let message):
                    failureView(message)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .refreshable {
            speech.stop()
            await model.load()
        }
        .sheet(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
    }

    // MARK: - Subviews

    private func stories(_ edition: Edition) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                speech.toggle(edition)
            } label: {
                Label(
                    speech.isPlaying ? "Pause" : "Listen to this edition",
                    systemImage: speech.isPlaying ? "pause.fill" : "play.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Capsule().stroke(Theme.purple.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)

            if model.isStale {
                Text("Showing the last saved edition — pull to refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            } else if let date = model.pastEditionDate {
                Label(
                    "Edition from \(ArchiveView.dayLabel(for: date)) — pull to refresh for today.",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Theme.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.purple.opacity(0.25), lineWidth: 1)
                )
                .padding(.bottom, 16)
            }

            ForEach(edition.stories) { story in
                StoryRow(story: story) {
                    speech.stop()
                    selectedStory = story
                    Prefs.shared.markRead(story)
                    PostHogSDK.shared.capture("story_opened", properties: ["url": story.url])
                }

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
    let onOpen: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// 22pt on iPad, 17pt on large iPhones (Pro Max class), 16pt otherwise,
    /// then scaled by the user's text-size preference.
    private var textSize: CGFloat {
        let base: CGFloat
        if sizeClass == .regular {
            base = 22
        } else {
            base = UIScreen.main.bounds.width >= 430 ? 17 : 16
        }
        return base * Prefs.shared.textSize.scale
    }

    var body: some View {
        let saved = SavedStore.shared.isSaved(story)
        let read = Prefs.shared.isRead(story)

        VStack(alignment: .leading, spacing: 12) {
            Group {
                Text(story.cleanIntro).fontWeight(.semibold)
                    + Text(" ")
                    + Text(story.cleanBody)
                    + Text(" ")
                    + Text(story.cleanLinkText)
                        .foregroundColor(Theme.purple)
                        .underline()
            }
            .font(.system(size: textSize))
            .foregroundStyle(Theme.text)
            .opacity(read ? 0.55 : 1)
            .lineSpacing(sizeClass == .regular ? 7 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            HStack(spacing: 22) {
                Button {
                    SavedStore.shared.toggle(story)
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved ? Theme.purple : Theme.secondary)
                }
                .buttonStyle(.plain)

                if let url = story.articleURL {
                    ShareLink(item: url, message: Text(story.cleanIntro)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Theme.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .font(.system(size: 15))
        }
        .padding(.vertical, sizeClass == .regular ? 20 : 16)
    }
}

// Lets a bare URL drive a `.sheet(item:)` (used by the Safari sheets).
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
