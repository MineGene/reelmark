import AppKit

/// What the Mac shows while Reelmark files a batch, as Finder does for a long
/// copy: a progress bar on the Dock icon, the Mac kept awake until the batch
/// is done, and one bounce of the Dock icon at the end if Reelmark is in the
/// background. A bounce rather than a notification, so there's no permission
/// to ask for and nothing left in Notification Centre.
@MainActor
final class FilingActivity {
    private var activity: NSObjectProtocol?
    private var bar: NSProgressIndicator?

    func start(total: Int) {
        // Copies to another drive can take a while; sleep would stop them.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: "Filing videos into the library")

        let tile = NSApp.dockTile
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.frame = NSRect(origin: .zero, size: tile.size)
        let bar = NSProgressIndicator(
            frame: NSRect(
                x: tile.size.width * 0.1, y: tile.size.height * 0.06,
                width: tile.size.width * 0.8, height: tile.size.height * 0.12))
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = Double(max(total, 1))
        icon.addSubview(bar)
        tile.contentView = icon
        tile.display()
        self.bar = bar
    }

    func update(done: Int) {
        bar?.doubleValue = Double(done)
        NSApp.dockTile.display()
    }

    func finish() {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        bar = nil
        NSApp.dockTile.contentView = nil
        NSApp.dockTile.display()
        if !NSApp.isActive { _ = NSApp.requestUserAttention(.informationalRequest) }
    }
}
