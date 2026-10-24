import AppKit
import ReelmarkCore
import SwiftUI

/// Reelmark › Settings (⌘,): the TMDB token, the two library folders, and
/// whether adding to the library copies or moves.
struct SettingsView: View {
    @Environment(LibraryModel.self) private var model
    @State private var tokenText = ""
    @State private var isChecking = false
    @State private var tokenError: String?
    @State private var folderError: String?

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                if model.ownToken != nil {
                    LabeledContent("Access token") {
                        HStack {
                            Label("Your own, saved in your Keychain", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.secondary)
                            Button("Remove") { model.removeToken() }
                        }
                    }
                } else {
                    LabeledContent("Access token") {
                        Text("Built in").foregroundStyle(.secondary)
                    }
                    SecureField("Your own token (optional)", text: $tokenText)
                    HStack {
                        Link(
                            "Get a free token at themoviedb.org",
                            destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                        Spacer()
                        if isChecking { ProgressView().controlSize(.small) }
                        Button("Save", action: saveToken)
                            .disabled(tokenText.isEmpty || isChecking)
                    }
                    if let tokenError {
                        Text(tokenError).foregroundStyle(.red)
                    }
                }
            } header: {
                Text("The Movie Database")
            } footer: {
                Text(
                    "Reelmark comes with its own access token, so there's nothing to set up. "
                        + "You can use your own TMDB token instead if you prefer. "
                        + "Only a title and year are ever sent to TMDB — never file names or folders. "
                        + "This product uses the TMDB API but is not endorsed or certified by TMDB."
                )
                .foregroundStyle(.secondary)
            }

            Section {
                FolderRow(title: "Movies", url: model.moviesFolder) { choose(.movie) }
                FolderRow(title: "Shows", url: model.showsFolder) { choose(.show) }
                if let folderError {
                    Text(folderError).foregroundStyle(.red)
                }
            } header: {
                Text("Jellyfin Library Folders")
            }

            Section {
                Picker("When adding to library", selection: $model.mode) {
                    Text("Copy").tag(MediaFiles.TransferMode.copy)
                    Text("Move").tag(MediaFiles.TransferMode.move)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func saveToken() {
        isChecking = true
        tokenError = nil
        Task {
            defer { isChecking = false }
            do {
                try await model.saveToken(tokenText)
                tokenText = ""
            } catch {
                tokenError = LibraryModel.describe(error)
            }
        }
    }

    private func choose(_ kind: Match.Kind) {
        Task {
            guard let url = await LibraryFolders.choose(kind, attachedTo: NSApp.keyWindow) else { return }
            do {
                try model.setFolder(url, for: kind)
                folderError = nil
            } catch {
                folderError = "Reelmark couldn't remember that folder: \(error.localizedDescription)"
            }
        }
    }
}

private struct FolderRow: View {
    let title: String
    let url: URL?
    let choose: () -> Void

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(url?.path(percentEncoded: false) ?? "Not chosen")
                    .lineLimit(1)
                    .truncationMode(.head)
                    .foregroundStyle(.secondary)
                Button("Choose…", action: choose)
            }
        }
    }
}
