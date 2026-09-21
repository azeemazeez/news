import SwiftUI
import UIKit
import WidgetKit

extension WidgetFamily {
    /// A stable name for analytics. `description` is not documented as stable,
    /// and the accessory families would otherwise arrive as noise.
    var analyticsName: String {
        switch self {
        case .systemSmall: "systemSmall"
        case .systemMedium: "systemMedium"
        case .systemLarge: "systemLarge"
        case .systemExtraLarge: "systemExtraLarge"
        default: "other"
        }
    }
}

/// The widget's layout. The family comes in as a value rather than from the
/// environment so the layout can also be rendered at a known size in previews.
struct HeadlinesLayout: View {
    let edition: Edition?
    let date: Date
    let family: WidgetFamily

    private var isLarge: Bool { family == .systemLarge }

    /// The medium widget has roughly 98pt under the header. Two stories with
    /// readable two-line summaries need about 121pt, so summaries there can
    /// only ever be a single truncated fragment — worse than nothing. It shows
    /// three headlines instead, which is what fits and what people scan.
    private var storyCount: Int { isLarge ? 4 : 3 }
    private var maxSummaryLines: Int { isLarge ? 3 : 0 }
    private var ruleSpacing: CGFloat { isLarge ? 9 : 6 }
    private let headlineGap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, isLarge ? 10 : 8)

            if let edition {
                GeometryReader { geo in
                    stories(edition.stories, in: geo.size)
                }
            } else {
                Spacer(minLength: 0)
                Text("Open The Nuus for today's edition.")
                    .font(.system(size: isLarge ? 16 : 15))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("The Nuus")
                .font(.custom("ArchivoBlack-Regular", size: isLarge ? 16 : 15))
                .foregroundStyle(Theme.wordmark)

            Spacer()

            Text(date.formatted(.dateTime.weekday(.abbreviated).month().day()))
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .kerning(0.4)
                .foregroundStyle(Theme.eyebrow)
        }
    }

    private func stories(_ stories: [Story], in size: CGSize) -> some View {
        let metrics = Metrics(headline: headlineFont(for: size), summary: summaryFont(for: size))
        let shown = Array(stories.prefix(fittingCount(stories, metrics: metrics, in: size)))
        let rules = CGFloat(max(shown.count - 1, 0)) * (ruleSpacing * 2 + 1)
        let plan = allocate(shown, metrics: metrics, width: size.width, height: size.height - rules)

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(zip(shown, plan).enumerated()), id: \.offset) { index, pair in
                let (story, lines) = pair

                if index > 0 {
                    // Spacers rather than fixed padding: whatever height is
                    // left over spreads evenly through the gaps instead of
                    // pooling into one dead band at the bottom.
                    Spacer(minLength: ruleSpacing)
                    Rectangle()
                        .fill(Theme.rule)
                        .frame(height: 1)
                    Spacer(minLength: ruleSpacing)
                }

                VStack(alignment: .leading, spacing: headlineGap) {
                    Text(story.cleanIntro)
                        .font(.system(size: metrics.headline.pointSize, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(lines.headline)

                    if lines.summary > 0 {
                        Text(story.cleanBody)
                            .font(.system(size: metrics.summary.pointSize))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(lines.summary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// How many stories can be shown with every headline complete. A headline
    /// cut off mid-word says less than one fewer story does, so on a narrow
    /// screen carrying long headlines the count gives way before the text is
    /// allowed to truncate.
    private func fittingCount(_ stories: [Story], metrics: Metrics, in size: CGSize) -> Int {
        var count = min(storyCount, stories.count)

        while count > 1 {
            let headlines = stories.prefix(count).reduce(CGFloat.zero) { total, story in
                let needed = metrics.lineCount(of: story.cleanIntro, font: metrics.headline, width: size.width)
                return total + CGFloat(min(needed, 2)) * metrics.headline.lineHeight
            }
            let rules = CGFloat(count - 1) * (ruleSpacing * 2 + 1)
            if headlines + rules <= size.height { break }
            count -= 1
        }
        return count
    }

    /// Hands out the space under the header a line at a time: every headline
    /// gets its first line, then the ones that wrap get their second, then the
    /// summaries share whatever is left. Widgets clip rather than scroll, so
    /// the number of lines has to be settled before anything is drawn.
    private func allocate(_ stories: [Story], metrics: Metrics, width: CGFloat, height: CGFloat) -> [(headline: Int, summary: Int)] {
        var plan = stories.map { _ in (headline: 1, summary: 0) }
        var left = height - CGFloat(stories.count) * metrics.headline.lineHeight

        for (index, story) in stories.enumerated()
        where metrics.lineCount(of: story.cleanIntro, font: metrics.headline, width: width) > 1 {
            guard left >= metrics.headline.lineHeight else { continue }
            plan[index].headline = 2
            left -= metrics.headline.lineHeight
        }

        for _ in 0..<maxSummaryLines {
            for index in plan.indices {
                let cost = metrics.summary.lineHeight + (plan[index].summary == 0 ? headlineGap : 0)
                guard left >= cost else { continue }
                plan[index].summary += 1
                left -= cost
            }
        }

        return plan
    }

    /// Narrow widgets (the 375pt-wide iPhones) get a slightly smaller scale so
    /// three headlines still fit without any of them truncating.
    private func headlineFont(for size: CGSize) -> UIFont {
        .systemFont(ofSize: isLarge ? 17 : (size.width < 300 ? 15 : 16), weight: .semibold)
    }

    private func summaryFont(for size: CGSize) -> UIFont {
        .systemFont(ofSize: isLarge ? 14 : (size.width < 300 ? 12.5 : 13))
    }
}

/// Text measurement, so the layout can work out how many lines fit.
private struct Metrics {
    let headline: UIFont
    let summary: UIFont

    func lineCount(of text: String, font: UIFont, width: CGFloat) -> Int {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(1, Int((bounds.height / font.lineHeight).rounded()))
    }
}
