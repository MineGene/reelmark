import Foundation

/// Looks titles up in The Movie Database (themoviedb.org), the same source
/// Jellyfin uses by default, so ids match what the server expects.
///
/// Privacy: the only things ever sent are a cleaned-up title, a year, and
/// a TMDB access token. File names, folder paths and anything
/// else about the user's files never leave the Mac. Requests go over HTTPS
/// with no cache, cookies or other stored state.
public struct TMDBClient: Sendable {

    public enum Failure: Error, Equatable {
        /// TMDB rejected the access token.
        case invalidToken
        /// Any other HTTP error, such as rate limiting (429).
        case http(Int)
        case badResponse
    }

    /// Up to this many candidates are kept per search, so a wrong first
    /// guess can be corrected without searching again.
    public static let maxResults = 6

    private let token: String
    private let session: URLSession
    private static let base = URL(string: "https://api.themoviedb.org/3/")!

    public init(token: String, session: URLSession = TMDBClient.makeSession()) {
        self.token = token
        self.session = session
    }

    /// A session that keeps nothing: no cache, no cookies, no credentials.
    public static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.timeoutIntervalForRequest = 15
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }

    /// Checks the access token without searching for anything.
    public func validateToken() async throws {
        _ = try await get("authentication", query: [])
    }

    /// Finds candidates for a parsed name: TV shows for episodes, movies
    /// otherwise. If nothing matches with the year, tries again without it
    /// (release years in file names are sometimes off by one).
    public func search(_ parsed: ParsedName) async throws -> [Match] {
        let kind: Match.Kind = parsed.isEpisode ? .show : .movie
        guard !parsed.title.isEmpty else { return [] }

        if let year = parsed.year {
            let yearKey = kind == .movie ? "year" : "first_air_date_year"
            let withYear = try await search(
                kind, title: parsed.title, extra: [URLQueryItem(name: yearKey, value: String(year))])
            if !withYear.isEmpty { return withYear }
        }
        return try await search(kind, title: parsed.title, extra: [])
    }

    // MARK: - Requests

    private func search(_ kind: Match.Kind, title: String, extra: [URLQueryItem]) async throws -> [Match] {
        let path = kind == .movie ? "search/movie" : "search/tv"
        let query =
            [URLQueryItem(name: "query", value: title), URLQueryItem(name: "include_adult", value: "false")]
            + extra
        return try Self.decodeSearch(try await get(path, query: query), kind: kind)
    }

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard
            var components = URLComponents(
                url: Self.base.appending(path: path), resolvingAgainstBaseURL: false)
        else { throw Failure.badResponse }
        components.queryItems = query.isEmpty ? nil : query
        // URLComponents leaves "+" alone, but servers read it as a space.
        let encoded = components.percentEncodedQuery?.replacing("+", with: "%2B")
        components.percentEncodedQuery = encoded
        guard let url = components.url else { throw Failure.badResponse }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.badResponse }
        switch http.statusCode {
        case 200: return data
        case 401: throw Failure.invalidToken
        default: throw Failure.http(http.statusCode)
        }
    }

    // MARK: - Decoding

    private struct SearchPage: Decodable {
        struct Result: Decodable {
            let id: Int
            let title: String?  // movies
            let name: String?  // shows
            let releaseDate: String?  // movies, "2024-02-27"
            let firstAirDate: String?  // shows
            let overview: String?
        }
        let results: [Result]
    }

    /// Public for tests, which use saved sample responses instead of the network.
    public static func decodeSearch(_ data: Data, kind: Match.Kind) throws -> [Match] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(SearchPage.self, from: data)
        return page.results.prefix(maxResults).compactMap { result in
            guard let title = result.title ?? result.name, !title.isEmpty else { return nil }
            let date = result.releaseDate ?? result.firstAirDate ?? ""
            return Match(
                id: result.id, kind: kind, title: title,
                year: Int(date.prefix(4)), overview: result.overview ?? "")
        }
    }
}
