import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // A single-window utility: closing the window quits, so nothing stays
    // in memory in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Finder's Services menu: "Add to Reelmark" (NSServices in Config/Info.plist).
        NSApp.servicesProvider = self
    }

    /// Videos or folders dropped on the Dock icon, or opened with Finder's
    /// Open With. macOS grants the sandbox access to them.
    func application(_ application: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated { LibraryModel.shared.add(urls) }
    }

    /// The Services menu item. Its name matches NSMessage in Info.plist.
    @objc func addFiles(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls =
            pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL] ?? []
        MainActor.assumeIsolated {
            NSApp.activate()
            LibraryModel.shared.add(urls)
        }
    }

    /// Right-clicking the Dock icon offers Add Files…, as in other Mac apps.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Add Files…", action: #selector(addFilesFromDock), keyEquivalent: "")
            .target = self
        return menu
    }

    @objc private func addFilesFromDock() {
        MainActor.assumeIsolated {
            NSApp.activate()
            LibraryModel.shared.isImporting = true
        }
    }
}

@main
struct ReelmarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = LibraryModel.shared

    var body: some Scene {
        Window("Reelmark", id: "main") {
            ContentView()
                .environment(model)
                // Small enough to tile in a quarter of a laptop screen, as
                // macOS window tiling does, beside Activity Monitor or Jellyfin.
                // Columns and toolbar buttons that don't fit scroll or move
                // into the toolbar's overflow menu, as in Finder.
                .frame(minWidth: 480, minHeight: 300)
        }
        // A fixed starting size, so a long list can't ask for a window taller
        // than the screen. macOS remembers any size the person chooses.
        .defaultSize(width: 960, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Reelmark") { AboutPanel.show() }
            }
            ReelmarkCommands(model: model)
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
