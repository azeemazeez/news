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

            // Keep checking every half hour until today's edition is actually in hand,
            // then settle down. Without this a single failed or early fetch left the
            // widget three hours behind.
            let isCurrent = edition?.date == WidgetNewsFetcher.expectedDate
            let minutes = isCurrent ? 180 : 30
            let refresh = Calendar.current.date(byAdding: .minute, value: minutes, to: .now)!

            completion(Timeline(entries: [HeadlinesEntry(date: .now, edition: edition)], policy: .after(refresh)))
        }
    }
}

enum WidgetNewsFetcher {
    private static let base = URL(string: "https://thenuus.com")!

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Editions are dated by UAE time (UTC+4), matching the cron that publishes them.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 4 * 3600)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// The edition date that should be published by now.
    static var expectedDate: String { dayFormatter.string(from: .now) }

    static func latest() async throws -> Edition {
        let manifest: Manifest = try await get("data/manifest.json")
        guard let date = manifest.dates.first else { throw URLError(.resourceUnavailable) }
        return try await get("data/\(date).json")
    }

    private static func get<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: base.appending(path: path))
        // Mirrors NewsService. Vercel caches these JSON files aggressively at the edge,
        // and on the default policy the widget re-read a stale manifest and so never
        // noticed a new edition had been published.
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 20

        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(T.self, from: data)
    }
}

extension Edition {
    /// Placeholder content for the widget gallery. Needs at least `storyCount`
    /// entries for the large family, or the preview renders short.
    static let sample = Edition(date: "2026-08-06", stories: [
        "The day's lead story", "A second headline", "Markets find their footing",
        "A breakthrough in the lab", "Talks resume after a long pause",
        "The quiet shift in energy", "A record falls at last",
        "What the new ruling changes", "A city rethinks its streets",
        "And the story to watch tomorrow",
    ].enumerated().map { index, intro in
        Story(
            intro: intro,
            body: "A concise summary of what happened and why it matters.",
            linkText: "",
            url: "https://thenuus.com/\(index + 1)",
            source: ""
        )
    })
}

// MARK: - Views

struct HeadlinesView: View {
    @Environment(\.widgetFamily) private var family

    let entry: HeadlinesEntry

    // Headlines are one line each, so these are sized to fill the widget rather
    // than leave a gap: roughly 27pt per row against the usable height.
    private var storyCount: Int { family == .systemLarge ? 10 : 4 }

    /// The date of the edition on screen — not the moment the timeline ran, which
    /// would advance daily and make stale content look current.
    private var headerDate: Date {
        guard let edition = entry.edition else { return entry.date }

        let parts = edition.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return entry.date }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]

        return Calendar.current.date(from: components) ?? entry.date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("The Nuus")
                    .font(.custom("ArchivoBlack-Regular", size: 16))
                    .foregroundStyle(Theme.wordmark)

                Spacer()

                Text(headerDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.system(size: 10, weight: .semibold))
                    .textCase(.uppercase)
                    .kerning(0.5)
                    .foregroundStyle(Theme.eyebrow)
            }
            .padding(.bottom, 6)

            if let edition = entry.edition {
                // Headlines only. The body copy is what forced two stories into the
                // space that comfortably holds several times that.
                ForEach(Array(edition.stories.prefix(storyCount).enumerated()), id: \.element.id) { index, story in
                    if index > 0 {
                        Rectangle()
                            .fill(Theme.rule)
                            .frame(height: 1)
                            .padding(.vertical, 5)
                    }
                    Text(story.cleanIntro)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
