import AppKit

/// Reelmark › About Reelmark: macOS's standard About panel (icon, name,
/// version and copyright come from the app itself) with a few lines of
/// credits. Plain text, no links: the app contains no web address but
/// TMDB's.
@MainActor
enum AboutPanel {
    static func show() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(
            string: """
                Renames movies and TV episodes the way Jellyfin expects, \
                using The Movie Database.

                Free and open source. Written by Claude, Anthropic's AI, \
                through Claude Code.

                This product uses the TMDB API but is not endorsed or certified by TMDB.
                """,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                // labelColor follows light and dark mode.
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }
}
