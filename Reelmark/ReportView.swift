import AppKit
import ReelmarkCore
import SwiftUI

/// The preview for Help › Report a Bug… and Request a Feature…: shows
/// exactly what would be shared, then opens a pre-filled GitHub issue in
/// the browser, where the person can change anything before submitting.
struct ReportView: View {
    let kind: IssueLink.Kind
    let model: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        let details = Diagnostics.report(for: model)
        VStack(alignment: .leading, spacing: 12) {
            Text(kind == .bug ? "Report a Bug" : "Request a Feature")
                .font(.headline)
            Text(
                "Reelmark will open a new issue on GitHub in your browser, with these details filled in. "
                    + "Nothing is sent until you submit it there, and you can change anything first. "
                    + "File names, folders and tokens are never included.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                Text(details)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 180)
            .background(.background.secondary, in: .rect(cornerRadius: 6))
            .accessibilityLabel("Details to share")
            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(details, forType: .string)
                }
                .help("Copy the details, to paste into an issue yourself")
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Open in Browser") {
                    if let url = link(details) { openURL(url) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    /// The issue form's fields: .github/ISSUE_TEMPLATE/bug.yml and feature.yml.
    private func link(_ details: String) -> URL? {
        switch kind {
        case .bug:
            IssueLink.url(
                .bug,
                fields: [
                    (id: "version", value: Diagnostics.appVersion),
                    (id: "macos", value: "\(Diagnostics.macOS), \(Diagnostics.mac)"),
                    (id: "diagnostics", value: details),
                ])
        case .feature:
            IssueLink.url(.feature, fields: [(id: "diagnostics", value: details)])
        }
    }
}
