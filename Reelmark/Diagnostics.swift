import AppKit
import MetricKit
import ReelmarkCore

/// What a bug report shares, shown to the person in full before anything
/// leaves the Mac: Reelmark's version, the Mac and macOS it runs on, the
/// settings and what the list holds, and summaries of recent crashes and
/// hangs. Never file names, folder paths or a token: problems are listed by
/// kind, and messages that could hold a name are left out.
@MainActor
enum Diagnostics {

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// For example "Version 26.1 (Build 25B78)".
    static var macOS: String { ProcessInfo.processInfo.operatingSystemVersionString }

    /// The Mac's model identifier, for example "Mac16,1".
    static var mac: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    static var memory: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory)
    }

    /// The whole report, as Markdown for the GitHub issue.
    static func report(for model: LibraryModel) -> String {
        var lines = [
            "- Reelmark: \(appVersion)",
            "- macOS: \(macOS)",
            "- Mac: \(mac), \(memory) of memory",
            "- Settings: \(model.mode == .copy ? "Copy" : "Move") to library; "
                + "Movies folder \(model.moviesFolder == nil ? "not chosen" : "chosen"); "
                + "Shows folder \(model.showsFolder == nil ? "not chosen" : "chosen"); "
                + "\(model.ownToken == nil ? "built-in" : "own") TMDB token",
            "- List: \(listSummary(model.items))",
        ]
        let problems = problemSummary(model.items)
        if !problems.isEmpty { lines.append("- Problems in the list: \(problems)") }
        lines.append("- Crashes and hangs macOS reported in the last day: \(CrashReports.summary)")
        return lines.joined(separator: "\n")
    }

    private static func listSummary(_ items: [LibraryModel.Item]) -> String {
        guard !items.isEmpty else { return "empty" }
        let counts: [(String, Int)] = [
            ("in library", items.count { $0.status == .done }),
            ("ready", items.count { $0.status == .ready }),
            ("no match", items.count { $0.status == .noMatch }),
            ("failed", items.count { if case .failed = $0.status { true } else { false } }),
            ("waiting", items.count { $0.status == .pending || $0.status == .searching }),
        ]
        let parts = counts.filter { $0.1 > 0 }.map { "\($0.1.formatted()) \($0.0)" }
        return "\(items.count.formatted()) items: " + parts.joined(separator: ", ")
    }

    /// Failures grouped by kind. Reelmark's own messages that never hold a
    /// name are kept; anything else (a file system error can quote a path)
    /// only counts as "other error".
    private static func problemSummary(_ items: [LibraryModel.Item]) -> String {
        var kinds: [String: Int] = [:]
        for item in items {
            guard case .failed(let message) = item.status else { continue }
            let kind =
                if message.hasPrefix("TMDB") || message.hasPrefix("Choose a")
                    || message == "You're offline."
                {
                    message
                } else if message.hasSuffix("is already in your library.") {
                    "already in the library"
                } else if message.hasPrefix("Couldn't undo") {
                    "couldn't undo"
                } else {
                    "other error"
                }
            kinds[kind, default: 0] += 1
        }
        return kinds.sorted { $0.key < $1.key }.map { "\($0.key) ×\($0.value)" }.joined(separator: "; ")
    }
}

/// Receives the crash and hang reports macOS keeps for Reelmark (Apple's
/// MetricKit), so a bug report can include their summaries. They stay on
/// the Mac; nothing is sent unless the person sends a bug report.
@MainActor
final class CrashReports: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReports()

    /// Registers to receive reports. macOS only keeps them for apps that ask.
    static func start() {
        MXMetricManager.shared.add(shared)
    }

    /// For example "1 crash (0.1.12: EXC_BAD_ACCESS, SIGSEGV); no hangs".
    static var summary: String {
        let payloads = MXMetricManager.shared.pastDiagnosticPayloads
        let crashes = payloads.flatMap { $0.crashDiagnostics ?? [] }
        let hangs = payloads.flatMap { $0.hangDiagnostics ?? [] }
        let crashText =
            crashes.isEmpty
            ? "no crashes"
            : "\(crashes.count) crash\(crashes.count == 1 ? "" : "es") ("
                + crashes.prefix(5).map { crash in
                    let parts = [
                        crash.metaData.applicationBuildVersion,
                        crash.exceptionType.map { "exception \($0)" },
                        crash.signal.map { "signal \($0)" },
                    ]
                    return parts.compactMap { $0 }.joined(separator: ", ")
                }.joined(separator: "; ") + ")"
        let hangText = hangs.isEmpty ? "no hangs" : "\(hangs.count) hang\(hangs.count == 1 ? "" : "s")"
        return "\(crashText); \(hangText)"
    }
}
