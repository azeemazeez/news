import Foundation

/// The list of every published edition, newest first.
struct Manifest: Decodable {
    let dates: [String]
}

/// A single day's digest.
struct Edition: Codable, Equatable {
    let date: String
    let stories: [Story]

    /// "Sunday, July 26, 2026" — matches the wording used on the site.
    var displayDate: String { Edition.displayDate(for: date) }

    static func displayDate(for date: String) -> String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return date }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]

        guard let day = Calendar.current.date(from: components) else { return date }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: day)
    }
}

struct Story: Codable, Equatable, Hashable, Identifiable {
    let intro: String
    let body: String
    let linkText: String
    let url: String
    let source: String

    var id: String { url }

    var articleURL: URL? { URL(string: url) }

    // The curation step occasionally leaves markdown bold markers in the copy.
    // The web app strips them at render time; do the same here.
    var cleanIntro: String { Story.strip(intro) }
    var cleanBody: String { Story.strip(body) }
    var cleanLinkText: String { Story.strip(linkText) }

    private static func strip(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
    }
}
