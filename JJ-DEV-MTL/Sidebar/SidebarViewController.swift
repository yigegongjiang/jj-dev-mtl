import Cocoa

final class SidebarViewController: NSViewController {

  var onSelectionChange: ((Tool) -> Void)?

  private let tools = ToolCatalog.all
  private let tableView = NSTableView()
  private let scrollView = NSScrollView()

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tool"))
    column.title = ""
    column.width = 240
    tableView.addTableColumn(column)
    tableView.headerView = nil
    tableView.style = .sourceList
    tableView.rowHeight = 30
    tableView.intercellSpacing = NSSize(width: 0, height: 2)
    tableView.dataSource = self
    tableView.delegate = self
    tableView.usesAutomaticRowHeights = false
    tableView.allowsMultipleSelection = false
    tableView.allowsEmptySelection = false
    tableView.focusRingType = .none

    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: container.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])

    self.view = container
  }

  func selectFirstIfNeeded() {
    guard tableView.selectedRow < 0, !tools.isEmpty else { return }
    tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
  }
}

extension SidebarViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int { tools.count }
}

extension SidebarViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("SidebarRow")
    let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? Self.makeCell(identifier: identifier)
    let tool = tools[row]
    cell.textField?.stringValue = tool.title
    cell.imageView?.image = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: nil)
    cell.imageView?.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
    return cell
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let row = tableView.selectedRow
    guard tools.indices.contains(row) else { return }
    onSelectionChange?(tools[row])
  }

  private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
    let cell = NSTableCellView()
    cell.identifier = identifier

    let icon = NSImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.imageScaling = .scaleProportionallyDown
    icon.contentTintColor = .secondaryLabelColor
    cell.imageView = icon
    cell.addSubview(icon)

    let label = NSTextField(labelWithString: "")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.lineBreakMode = .byTruncatingTail
    label.font = .systemFont(ofSize: NSFont.systemFontSize)
    cell.textField = label
    cell.addSubview(label)

    NSLayoutConstraint.activate([
      icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
      icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      icon.widthAnchor.constraint(equalToConstant: 18),
      icon.heightAnchor.constraint(equalToConstant: 18),

      label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
      label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
      label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])

    return cell
  }
}
