import SwiftUI
import UIKit
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

            // Only the timeline is reported. `getSnapshot` also runs while
            // someone is merely browsing the widget gallery, which is not the
            // same thing as having the widget on a home screen.
            Analytics.startForWidget()
            Analytics.widgetRendered(
                family: context.family.analyticsName,
                hasEdition: edition != nil
            )

            // Keep checking every half hour until today's edition is actually in
            // hand, then settle down. Backing off to three hours after a fetch
            // that failed or landed before publication left the widget a day behind.
            let isCurrent = edition?.date == WidgetNewsFetcher.expectedDate
            let refresh = Calendar.current.date(byAdding: .minute, value: isCurrent ? 180 : 30, to: .now)!

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
        // Mirrors NewsService. Vercel caches these JSON files aggressively at the
        // edge, and on the default policy the widget re-read a stale manifest and
        // so never noticed a new edition had been published.
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 20

        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder.decode(T.self, from: data)
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

    /// The date of the edition on screen — not the moment the timeline ran, which
    /// would advance every morning and make stale content look current.
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
        HeadlinesLayout(edition: entry.edition, date: headerDate, family: family)
            .containerBackground(for: .widget) { Theme.background }
            // Tapping opens the app, which reports the tap from `onOpenURL`.
            // The widget process is long gone by then, so it cannot send this
            // one itself.
            .widgetURL(URL(string: "thenuus://widget?family=\(family.analyticsName)"))
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
