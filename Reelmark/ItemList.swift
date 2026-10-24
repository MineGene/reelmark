import AppKit
import ReelmarkCore
import SwiftUI

/// The list of files, drawn with AppKit's NSTableView: the same table Finder
/// and Mail use, and the one SwiftUI's Table is built on.
///
/// Why not SwiftUI's Table: it builds a separate SwiftUI view tree for every
/// cell, which cost about 0.7 MB per row (155 MB for a list of about 190
/// files). These cells are plain AppKit labels, menus and images costing a
/// few kilobytes each, and the table only keeps the rows on screen.
///
/// It behaves the same: click a header to sort (again to reverse), select
/// several rows, Delete removes them, right-click for Search Again… and
/// Remove from List, choose between possible matches, and hover for help.
struct ItemList: NSViewRepresentable {
    typealias Item = LibraryModel.Item

    let model: LibraryModel
    @Binding var selection: Set<Item.ID>
    let onSearch: (Item.ID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = DeletingTableView()
        table.onDelete = { [weak coordinator = context.coordinator] in coordinator?.removeSelection() }
        table.style = .inset
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        for column in Column.allCases { table.addTableColumn(column.tableColumn) }
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        let menu = NSMenu()
        menu.delegate = context.coordinator
        table.menu = menu
        // The table takes drops itself: SwiftUI's drop area around it doesn't
        // reach over an AppKit view, so drops on the list were refused.
        table.registerForDraggedTypes([.fileURL])
        context.coordinator.table = table

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.show(model.items, selection: selection)
    }

    // MARK: - Columns

    enum Column: String, CaseIterable {
        case file, match, newName, status

        @MainActor var tableColumn: NSTableColumn {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue))
            // Clicking the header sorts A to Z, clicking again Z to A.
            column.sortDescriptorPrototype = NSSortDescriptor(key: rawValue, ascending: true)
            switch self {
            case .file: column.title = "Downloaded File"
            case .match: column.title = "Match"
            case .newName: column.title = "New Name"
            case .status:
                column.title = ""
                column.width = 24
                column.resizingMask = []
                return column
            }
            column.width = 240
            column.minWidth = 80
            return column
        }
    }

    // MARK: - Table

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
        var parent: ItemList
        weak var table: NSTableView?
        /// The items in the order shown (sorted by the clicked header, if any).
        private var rows: [Item] = []
        private var isSyncingSelection = false

        init(_ parent: ItemList) { self.parent = parent }

        /// Shows the model's items. Rows are only reloaded when an item
        /// actually changed, so a click on a row's menu isn't interrupted.
        func show(_ items: [Item], selection: Set<Item.ID>) {
            guard let table else { return }
            let sorted = Self.sorted(items, by: table.sortDescriptors)
            if sorted != rows {
                rows = sorted
                table.reloadData()
            }
            let wanted = IndexSet(rows.indices.filter { selection.contains(rows[$0].id) })
            if wanted != table.selectedRowIndexes {
                isSyncingSelection = true
                table.selectRowIndexes(wanted, byExtendingSelection: false)
                isSyncingSelection = false
            }
        }

        private static func sorted(_ items: [Item], by descriptors: [NSSortDescriptor]) -> [Item] {
            guard let first = descriptors.first, let column = Column(rawValue: first.key ?? "") else {
                return items  // the order they were added
            }
            let order: SortOrder = first.ascending ? .forward : .reverse
            // Names compare the way Finder does: "Episode 2" before "Episode 10".
            return switch column {
            case .file:
                items.sorted(
                    using: KeyPathComparator(\.fileName, comparator: .localizedStandard, order: order))
            case .match:
                items.sorted(
                    using: KeyPathComparator(\.matchName, comparator: .localizedStandard, order: order))
            case .newName:
                items.sorted(
                    using: KeyPathComparator(\.newName, comparator: .localizedStandard, order: order))
            case .status: items.sorted(using: KeyPathComparator(\.statusRank, order: order))
            }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
        {
            show(parent.model.items, selection: parent.selection)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isSyncingSelection, let table else { return }
            parent.selection = Set(
                table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0].id : nil })
        }

        func removeSelection() {
            guard let table else { return }
            parent.model.remove(
                Set(table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0].id : nil }))
        }

        // MARK: Dropping files

        /// Files dropped anywhere on the list are added, and the whole table
        /// is highlighted while they're held over it, as in Finder.
        func tableView(
            _ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
            proposedDropOperation dropOperation: NSTableView.DropOperation
        ) -> NSDragOperation {
            guard info.draggingSource == nil else { return [] }  // not a drag from within the app
            tableView.setDropRow(-1, dropOperation: .on)
            return .copy
        }

        func tableView(
            _ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int,
            dropOperation: NSTableView.DropOperation
        ) -> Bool {
            let urls =
                info.draggingPasteboard.readObjects(
                    forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            guard !urls.isEmpty else { return false }
            parent.model.add(urls)
            return true
        }

        // MARK: Cells

        func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let identifier = tableColumn?.identifier.rawValue,
                let column = Column(rawValue: identifier),
                rows.indices.contains(row)
            else { return nil }
            let item = rows[row]
            switch column {
            case .file:
                return label(
                    in: tableView, item.fileName, truncation: .byTruncatingMiddle, help: item.fileName)
            case .match:
                return matchCell(in: tableView, for: item)
            case .newName:
                return label(
                    in: tableView, item.newPath ?? "—", truncation: .byTruncatingHead,
                    dimmed: item.newPath == nil, help: item.newPath)
            case .status:
                return statusCell(in: tableView, for: item.status)
            }
        }

        private func matchCell(in table: NSTableView, for item: Item) -> NSView {
            switch item.status {
            case .pending: return label(in: table, "Waiting…", dimmed: true)
            case .searching: return label(in: table, "Searching…", dimmed: true)
            case .noMatch: return label(in: table, "No match — right-click to search again", dimmed: true)
            case .failed(let message): return label(in: table, message, dimmed: true, help: message)
            case .ready where item.candidates.count > 1:
                let cell = reuse(MenuCell.self, in: table)
                cell.show(
                    item.candidates, selected: item.matchID, target: self, action: #selector(chooseMatch(_:)))
                return cell
            case .ready, .done:
                return label(in: table, item.match?.displayName ?? "—", help: item.match?.overview)
            }
        }

        @objc private func chooseMatch(_ sender: NSPopUpButton) {
            guard let table else { return }
            let row = table.row(for: sender)
            guard rows.indices.contains(row) else { return }
            parent.model.choose(sender.selectedTag(), for: rows[row].id)
        }

        /// The hover text says why the icon is there; VoiceOver reads the same.
        private func statusCell(in table: NSTableView, for status: Item.Status) -> NSView {
            let cell = reuse(IconCell.self, in: table)
            switch status {
            case .done:
                cell.show(
                    "checkmark.circle.fill", color: .systemGreen, label: "In your library",
                    help: "In your library")
            case .noMatch:
                cell.show(
                    "exclamationmark.triangle.fill", color: .systemYellow, label: "Needs attention",
                    help: "Not found on The Movie Database. Right-click and choose Search Again… "
                        + "to try a different title.")
            case .failed(let message):
                cell.show(
                    "exclamationmark.triangle.fill", color: .systemYellow, label: "Needs attention",
                    help: message)
            default:
                cell.show(nil, color: nil, label: nil, help: nil)
            }
            return cell
        }

        private func label(
            in table: NSTableView, _ text: String, truncation: NSLineBreakMode = .byTruncatingTail,
            dimmed: Bool = false, help: String? = nil
        ) -> NSView {
            let cell = reuse(LabelCell.self, in: table)
            cell.show(text, truncation: truncation, dimmed: dimmed, help: help)
            return cell
        }

        /// A cell from the table's reuse pool, or a new one.
        private func reuse<Cell: NSView>(_ type: Cell.Type, in table: NSTableView) -> Cell {
            let identifier = NSUserInterfaceItemIdentifier(String(describing: type))
            if let cell = table.makeView(withIdentifier: identifier, owner: nil) as? Cell { return cell }
            let cell = Cell()
            cell.identifier = identifier
            return cell
        }

        // MARK: Right-click menu

        /// Right-clicking a selected row acts on the whole selection, as in
        /// Finder; right-clicking any other row acts on just that row.
        private var menuTargets: [Item.ID] = []

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            guard let table, rows.indices.contains(table.clickedRow) else { return }
            let indexes =
                table.selectedRowIndexes.contains(table.clickedRow)
                ? table.selectedRowIndexes : IndexSet(integer: table.clickedRow)
            menuTargets = indexes.compactMap { rows.indices.contains($0) ? rows[$0].id : nil }
            if menuTargets.count == 1 {
                menu.addItem(withTitle: "Search Again…", action: #selector(searchAgain), keyEquivalent: "")
                    .target = self
            }
            menu.addItem(withTitle: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Remove from List", action: #selector(removeTargets), keyEquivalent: "")
                .target = self
        }

        @objc private func searchAgain() {
            if let id = menuTargets.first { parent.onSearch(id) }
        }

        @objc private func showInFinder() {
            parent.model.showInFinder(Set(menuTargets))
        }

        @objc private func removeTargets() {
            parent.model.remove(Set(menuTargets))
        }
    }
}

// MARK: - Table and cells

/// Delete (or forward delete) removes the selected rows, as in Finder.
final class DeletingTableView: NSTableView {
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.specialKey == .delete || event.specialKey == .deleteForward {
            onDelete?()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// One line of text, vertically centred, truncated to fit.
private final class LabelCell: NSTableCellView {
    private let field = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(field)
        textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("Not used in a storyboard") }

    func show(_ text: String, truncation: NSLineBreakMode, dimmed: Bool, help: String?) {
        field.stringValue = text
        field.lineBreakMode = truncation
        field.textColor = dimmed ? .secondaryLabelColor : .labelColor
        field.toolTip = help
    }
}

/// A pop-up menu of possible matches.
private final class MenuCell: NSTableCellView {
    private let popUp = NSPopUpButton(frame: .zero, pullsDown: false)

    override init(frame: NSRect) {
        super.init(frame: frame)
        popUp.translatesAutoresizingMaskIntoConstraints = false
        popUp.controlSize = .small
        popUp.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(popUp)
        NSLayoutConstraint.activate([
            popUp.leadingAnchor.constraint(equalTo: leadingAnchor),
            popUp.trailingAnchor.constraint(equalTo: trailingAnchor),
            popUp.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("Not used in a storyboard") }

    func show(_ matches: [Match], selected: Int?, target: AnyObject, action: Selector) {
        popUp.removeAllItems()
        for match in matches {
            popUp.addItem(withTitle: match.displayName)
            popUp.lastItem?.tag = match.id
            popUp.lastItem?.toolTip = match.overview
        }
        if let selected { popUp.selectItem(withTag: selected) }
        popUp.toolTip = popUp.selectedItem?.toolTip
        popUp.target = target
        popUp.action = action
    }
}

/// A status icon with hover help.
private final class IconCell: NSTableCellView {
    private let icon = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("Not used in a storyboard") }

    func show(_ symbol: String?, color: NSColor?, label: String?, help: String?) {
        icon.image = symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: label) }
        icon.contentTintColor = color
        icon.toolTip = help
        icon.setAccessibilityHelp(help)
    }
}
