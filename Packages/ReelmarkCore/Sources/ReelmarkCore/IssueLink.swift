import Foundation

/// Links to a new issue on Reelmark's GitHub repository, with the issue
/// form's fields filled in, for Help › Report a Bug… and Request a
/// Feature…. The app never fetches this address: it only hands it to the
/// person's browser when they choose to, and they read and submit the
/// issue themselves.
public enum IssueLink {
    public enum Kind: String, Sendable {
        case bug, feature
    }

    /// The only web address in the app besides TMDB's; scripts/check-app.sh
    /// allows exactly this.
    public static let newIssue = "https://github.com/MineGene/reelmark/issues/new"

    /// Browsers and GitHub cope with addresses up to about 8,000 characters,
    /// so longer field values are cut short to stay under that.
    public static let maxLength = 7_000

    /// A new-issue link using the `kind` issue form (.github/ISSUE_TEMPLATE),
    /// with `fields` (form field id, value) filled in.
    public static func url(_ kind: Kind, fields: [(id: String, value: String)]) -> URL? {
        guard var components = URLComponents(string: newIssue) else { return nil }
        let budget = max(0, maxLength / max(fields.count, 1) - 64)
        components.queryItems =
            [URLQueryItem(name: "template", value: "\(kind.rawValue).yml")]
            + fields.map { URLQueryItem(name: $0.id, value: String($0.value.prefix(budget))) }
        // URLComponents leaves "+" alone, but GitHub reads it as a space.
        // (Read into a local first: reading and writing components in one
        // statement breaks Swift's exclusive-access rule.)
        let encoded = components.percentEncodedQuery?.replacing("+", with: "%2B")
        components.percentEncodedQuery = encoded
        return components.url
    }
}
