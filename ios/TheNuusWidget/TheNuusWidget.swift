import SwiftUI
import WidgetKit

// MARK: - Timeline

struct HeadlinesEntry: TimelineEntry {
    let date: Date
    let edition: Edition?
}

struct HeadlinesProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeadlinesEntry {
        HeadlinesEntry(date: .now, edition: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeadlinesEntry) -> Void) {
        completion(HeadlinesEntry(date: .now, edition: .sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeadlinesEntry>) -> Void) {
        Task {
            let edition = try? await WidgetNewsFetcher.latest()
            let refresh = Calendar.current.date(byAdding: .hour, value: edition == nil ? 1 : 3, to: .now)!
            completion(Timeline(entries: [HeadlinesEntry(date: .now, edition: edition)], policy: .after(refresh)))
        }
    }
}

enum WidgetNewsFetcher {
    static func latest() async throws -> Edition {
        let base = URL(string: "https://thenuus.com")!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let (manifestData, _) = try await URLSession.shared.data(from: base.appending(path: "data/manifest.json"))
        let manifest = try decoder.decode(Manifest.self, from: manifestData)
        guard let date = manifest.dates.first else { throw URLError(.resourceUnavailable) }

        let (editionData, _) = try await URLSession.shared.data(from: base.appending(path: "data/\(date).json"))
        return try decoder.decode(Edition.self, from: editionData)
    }
}

extension Edition {
    /// Placeholder content for the widget gallery.
    static let sample = Edition(date: "2026-08-06", stories: [
        Story(intro: "The day's top story appears here", body: "with a concise summary of what happened and why it matters.", linkText: "", url: "https://thenuus.com/1", source: ""),
        Story(intro: "A second headline", body: "so you can scan the morning's news at a glance.", linkText: "", url: "https://thenuus.com/2", source: ""),
        Story(intro: "A third story", body: "rounds out the digest.", linkText: "", url: "https://thenuus.com/3", source: ""),
        Story(intro: "And a fourth", body: "for the large widget.", linkText: "", url: "https://thenuus.com/4", source: ""),
    ])
}

// MARK: - Views

struct HeadlinesView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HeadlinesEntry

    private var storyCount: Int { family == .systemLarge ? 4 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("The Nuus")
                    .font(.custom("ArchivoBlack-Regular", size: 16))
                    .foregroundStyle(Theme.wordmark)

                Spacer()

                Text(entry.date.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .foregroundStyle(Theme.eyebrow)
            }
            .padding(.bottom, 8)

            if let edition = entry.edition {
                ForEach(Array(edition.stories.prefix(storyCount).enumerated()), id: \.element.id) { index, story in
                    if index > 0 {
                        Rectangle()
                            .fill(Theme.rule)
                            .frame(height: 1)
                            .padding(.vertical, 6)
                    }
                    Group {
                        Text(story.cleanIntro).fontWeight(.semibold)
                            + Text(" ")
                            + Text(story.cleanBody)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text)
                    .lineLimit(family == .systemLarge ? 3 : 2)
                }
            } else {
                Spacer()
                Text("Open The Nuus for today's edition.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
            }

            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { Theme.background }
    }
}

// MARK: - Widget

@main
struct TheNuusWidgetBundle: WidgetBundle {
    var body: some Widget {
        TheNuusWidget()
    }
}

struct TheNuusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TheNuusHeadlines", provider: HeadlinesProvider()) { entry in
            HeadlinesView(entry: entry)
        }
        .configurationDisplayName("Today's Headlines")
        .description("The top stories from today's edition of The Nuus.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
