import SwiftUI

enum MenuScreen: String, Identifiable {
    case archive, saved, settings, about
    var id: String { rawValue }
}

// MARK: - Archive

struct ArchiveView: View {
    /// Called with the picked date; the feed loads that edition.
    let onSelect: (String) -> Void

    @State private var available: Set<String> = []
    @State private var range: ClosedRange<Date>?
    @State private var selected = Date()
    @State private var noEdition = false
    @State private var failed = false

    var body: some View {
        Group {
            if failed {
                Text("Couldn't load the archive.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.secondary)
            } else if let range {
                Form {
                    Section {
                        DatePicker(
                            "Edition date",
                            selection: $selected,
                            in: range,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .onChange(of: selected) { _, day in
                            let key = Self.key(for: day)
                            if available.contains(key) {
                                noEdition = false
                                onSelect(key)
                            } else {
                                noEdition = true
                            }
                        }
                    } footer: {
                        Text(noEdition
                             ? "No edition was published on that day — try another."
                             : "Pick a day to read that edition.")
                    }
                }
            } else {
                ProgressView().tint(Theme.purple)
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let dates = try await NewsService.shared.manifestDates()
                available = Set(dates)
                let days = dates.compactMap(Self.parse)
                if let newest = days.max(), let oldest = days.min() {
                    selected = newest
                    range = oldest...newest
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }

    private static func parse(_ date: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: date)
    }

    private static func key(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: day)
    }

    static func dayLabel(for date: String) -> String {
        guard let day = parse(date) else { return date }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

// MARK: - Saved

struct SavedView: View {
    var body: some View {
        Group {
            if SavedStore.shared.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.secondary)
                    Text("No saved stories yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Save any story from its reading screen or by long-pressing it in the feed.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(SavedStore.shared.items) { item in
                        NavigationLink(value: ReadRequest(story: item.story, editionDate: item.editionDate)) {
                            VStack(alignment: .leading, spacing: 6) {
                                if let date = item.editionDate {
                                    Text(Edition.displayDate(for: date))
                                        .font(.system(size: 11, weight: .semibold))
                                        .kerning(1.0)
                                        .textCase(.uppercase)
                                        .foregroundStyle(Theme.secondary)
                                }

                                Group {
                                    Text(item.story.cleanIntro).fontWeight(.semibold)
                                        + Text(" ")
                                        + Text(item.story.cleanBody)
                                }
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.text)
                                .lineLimit(3)
                            }
                            .padding(.vertical, 8)
                        }
                        .listRowBackground(Theme.background)
                        .listRowSeparatorTint(Theme.rule)
                    }
                    .onDelete { SavedStore.shared.remove(atOffsets: $0) }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutView: View {
    private static let paragraphs = [
        "The Nuus is a daily news digest built on a simple idea: the stories that matter most, told clearly and without the noise.",
        "Keeping up with the world shouldn't mean juggling a dozen sources, sifting through ads, or hitting paywalls before you've had your first coffee. The Nuus was built to change that: a single, curated view of what's happening right now, delivered every morning.",
        "We pull from sources across the web and filter for the stories that deserve your attention. Not the loudest headlines. Not the most clicked. The ones with real significance — for curious, informed readers who value their time.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Self.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(5)
                }

                Text("The Nuus is a [MonoBlock](https://monoblock.ae) endeavor.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .tint(Theme.purple)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
