import SwiftUI

enum MenuScreen: String, Identifiable {
    case archive, about
    var id: String { rawValue }
}

// MARK: - Archive

struct ArchiveView: View {
    struct MonthGroup: Identifiable {
        let title: String
        let dates: [String]
        var id: String { title }
    }

    @State private var groups: [MonthGroup] = []
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if failed {
                    Text("Couldn't load the archive.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                } else if groups.isEmpty {
                    ProgressView().tint(Theme.purple)
                } else {
                    List {
                        ForEach(groups) { group in
                            Section(group.title) {
                                ForEach(group.dates, id: \.self) { date in
                                    NavigationLink(Self.dayLabel(for: date)) {
                                        EditionView(date: date)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.purple)
        .task {
            do {
                groups = Self.grouped(try await NewsService.shared.manifestDates())
            } catch {
                failed = true
            }
        }
    }

    static func grouped(_ dates: [String]) -> [MonthGroup] {
        var order: [String] = []
        var buckets: [String: [String]] = [:]
        for date in dates {
            let title = monthLabel(for: date)
            if buckets[title] == nil { order.append(title) }
            buckets[title, default: []].append(date)
        }
        return order.map { MonthGroup(title: $0, dates: buckets[$0] ?? []) }
    }

    private static func parse(_ date: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: date)
    }

    static func monthLabel(for date: String) -> String {
        guard let day = parse(date) else { return date }
        return day.formatted(.dateTime.month(.wide).year())
    }

    static func dayLabel(for date: String) -> String {
        guard let day = parse(date) else { return date }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

struct EditionView: View {
    let date: String

    @State private var edition: Edition?
    @State private var failed = false
    @State private var selectedArticle: URL?

    var body: some View {
        Group {
            if let edition {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
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
            } else if failed {
                Text("Couldn't load this edition.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
            } else {
                ProgressView().tint(Theme.purple)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(ArchiveView.dayLabel(for: date))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                edition = try await NewsService.shared.edition(for: date)
            } catch {
                failed = true
            }
        }
        .sheet(item: $selectedArticle) { url in
            SafariView(url: url).ignoresSafeArea()
        }
    }
}

// MARK: - About

struct AboutView: View {
    private static let paragraphs = [
        "The Nuus is a daily news digest built on a simple idea: the stories that matter most, told clearly and without the noise.",
        "Keeping up with the world shouldn't mean juggling a dozen sources, sifting through ads, or hitting paywalls before you've had your first coffee. The Nuus was built to change that — a single, curated view of what's happening right now, delivered every morning.",
        "We pull from sources across the web and filter for the stories that deserve your attention. Not the loudest headlines. Not the most clicked. The ones with real significance — for curious, informed readers who value their time.",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Self.paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.text)
                            .lineSpacing(5)
                    }

                    Text("The Nuus — A MonoBlock Endeavor")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Theme.purple)
    }
}
