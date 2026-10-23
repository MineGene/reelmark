import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // A single-window utility: closing the window quits, so nothing stays
    // in memory in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ReelmarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = LibraryModel()

    var body: some Scene {
        Window("Reelmark", id: "main") {
            ContentView()
                .environment(model)
                .frame(minWidth: 760, minHeight: 420)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Reelmark") { AboutPanel.show() }
            }
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") { model.isImporting = true }
                    .keyboardShortcut("o")
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
