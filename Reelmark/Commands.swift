import ReelmarkCore
import SwiftUI

/// What the menu bar acts on: the main window's list and selection. The
/// window only offers it while it's in front and no sheet is open, so
/// shortcuts like Command-Delete never reach the list from Settings or
/// from the Search Again text field.
struct ListCommands {
    let model: LibraryModel
    let selection: Set<LibraryModel.Item.ID>
    let fileReady: () -> Void
    let searchAgain: (LibraryModel.Item.ID) -> Void
}

extension FocusedValues {
    @Entry var listCommands: ListCommands?
}

/// File menu items, with the standard shortcuts from Apple's Human Interface
/// Guidelines where one exists, and Finder's where Finder has the same
/// command (Command-Delete removes, Command-R for the item's search).
struct ReelmarkCommands: Commands {
    let model: LibraryModel
    @FocusedValue(\.listCommands) private var list

    var body: some Commands {
        CommandGroup(after: .help) {
            Divider()
            Button("Report a Bug…") { model.report = .bug }
            Button("Request a Feature…") { model.report = .feature }
        }
        CommandGroup(replacing: .newItem) {
            Button("Add Files…") { model.isImporting = true }
                .keyboardShortcut("o")
        }
        CommandGroup(after: .newItem) {
            Divider()
            Button(model.mode == .copy ? "Copy to Library" : "Move to Library") { list?.fileReady() }
                .keyboardShortcut(.return)
                .disabled(list == nil || model.readyCount == 0 || model.isRenaming)
            Divider()
            Button("Search Again…") {
                if let list, let id = list.selection.first { list.searchAgain(id) }
            }
            .keyboardShortcut("r")
            .disabled(list?.selection.count != 1)
            Button("Show in Finder") {
                if let list { model.showInFinder(list.selection) }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(list?.selection.isEmpty ?? true)
            Divider()
            Button("Remove from List") {
                if let list { model.remove(list.selection) }
            }
            .keyboardShortcut(.delete)
            .disabled(list?.selection.isEmpty ?? true)
            Button("Clear List") { model.clear() }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
                .disabled(list == nil || model.items.isEmpty || model.isRenaming)
            Button("Stop Adding Files") { model.stopScanning() }
                .keyboardShortcut(".")
                .disabled(list == nil || !model.isScanning)
        }
    }
}
