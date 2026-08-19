import PostHog
import SwiftUI

/// Native reading screen for a single story: full digest text with reader
/// typography, listen/save/share actions, and the original source demoted
/// to a footer link.
struct StoryDetailView: View {
    let story: Story

    @Environment(\.openURL) private var openURL
    @State private var speech = SpeechController()

    private var prefs: Prefs { Prefs.shared }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(story.source)
                        .font(.system(size: 12, weight: .bold))
                        .kerning(2.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.purple)

                    Text(story.cleanIntro)
                        .font(.system(size: 27 * prefs.textSize.scale, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(5)
                        .padding(.top, 12)

                    Text(story.cleanBody)
                        .font(.system(size: 18 * prefs.textSize.scale, design: .serif))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(8)
                        .padding(.top, 18)

                    actionRow
                        .padding(.top, 28)

                    if let url = story.articleURL {
                        Rectangle()
                            .fill(Theme.rule)
                            .frame(height: 1)
                            .padding(.vertical, 24)

                        Button {
                            openURL(url)
                            PostHogSDK.shared.capture("article_opened", properties: ["url": url.absoluteString])
                        } label: {
                            Label("Read the full story at \(story.source)", systemImage: "arrow.up.right.square")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.purple)
                        }
                        .buttonStyle(.plain)
                    }
                }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Text Size", selection: Bindable(Prefs.shared).textSize) {
                        ForEach(Prefs.TextSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .accessibilityLabel("Text size")
                }
            }
        }
        .onDisappear { speech.stop() }
    }

    private var actionRow: some View {
        let saved = SavedStore.shared.isSaved(story)

        return HStack(spacing: 26) {
            Button {
                speech.toggle(story)
            } label: {
                Label(
                    speech.isPlaying ? "Pause" : "Listen",
                    systemImage: speech.isPlaying ? "pause.fill" : "play.fill"
                )
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.purple)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(Capsule().stroke(Theme.purple.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                SavedStore.shared.toggle(story)
            } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(saved ? Theme.purple : Theme.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(saved ? "Remove from saved" : "Save story")
            .accessibilityIdentifier("reader-save")

            if let url = story.articleURL {
                ShareLink(item: url, message: Text(story.cleanIntro)) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share story")
            }

            Spacer()
        }
        .font(.system(size: 17))
        .sensoryFeedback(.impact(weight: .light), trigger: saved)
    }
}
