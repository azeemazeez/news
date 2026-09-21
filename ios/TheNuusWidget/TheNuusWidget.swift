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

    var body: some View {
        HeadlinesLayout(edition: entry.edition, date: entry.date, family: family)
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
