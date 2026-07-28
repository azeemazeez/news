import Foundation

enum NewsError: LocalizedError {
    case noEditions
    case badStatus(Int)
    case offline

    var errorDescription: String? {
        switch self {
        case .noEditions:
            return "No editions have been published yet."
        case .badStatus(let code):
            return "The server returned an error (\(code))."
        case .offline:
            return "You appear to be offline."
        }
    }
}

/// Fetches editions from thenuus.com and keeps the most recent one on disk so
/// the app still has something to show without a connection.
struct NewsService {
    static let shared = NewsService()

    private let baseURL = URL(string: "https://thenuus.com")!

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    // MARK: - Fetching

    func latestEdition() async throws -> Edition {
        let manifest: Manifest = try await fetch("data/manifest.json")
        guard let latest = manifest.dates.first else { throw NewsError.noEditions }

        let edition: Edition = try await fetch("data/\(latest).json")
        cache(edition)
        return edition
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appending(path: path)

        var request = URLRequest(url: url)
        // Editions change once a day and Vercel caches aggressively at the edge.
        request.cachePolicy = .reloadRevalidatingCacheData
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw NewsError.badStatus(-1)
            }
            guard (200..<300).contains(http.statusCode) else {
                throw NewsError.badStatus(http.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw NewsError.offline
        }
    }

    // MARK: - Offline cache

    private var cacheURL: URL? {
        try? FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "latest-edition.json")
    }

    private func cache(_ edition: Edition) {
        guard let cacheURL, let data = try? JSONEncoder().encode(edition) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    func cachedEdition() -> Edition? {
        guard let cacheURL, let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Edition.self, from: data)
    }
}
