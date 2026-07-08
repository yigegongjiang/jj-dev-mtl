import Cocoa

// 侧栏行: 序号(替代图标, 提示按对应数字键选中) + 工具名
final class ToolCellView: NSTableCellView {
  let numberLabel = NSTextField(labelWithString: "")
  override var backgroundStyle: NSView.BackgroundStyle {
    didSet { numberLabel.textColor = backgroundStyle == .emphasized ? .white : .secondaryLabelColor }
  }
}

final class SidebarViewController: NSViewController {

  var onSelectionChange: ((Tool) -> Void)?

  private let tools = ToolCatalog.all
  private let tableView = NSTableView()
  private let scrollView = NSScrollView()

  var toolCount: Int { tools.count }

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

  // 数字键选中对应工具
  func selectTool(at index: Int) {
    guard tools.indices.contains(index) else { return }
    tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
    tableView.scrollRowToVisible(index)
  }
}

extension SidebarViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int { tools.count }
}

extension SidebarViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let identifier = NSUserInterfaceItemIdentifier("SidebarRow")
    let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ToolCellView ?? Self.makeCell(identifier: identifier)
    cell.textField?.stringValue = tools[row].title
    cell.numberLabel.stringValue = "\(row + 1)"
    return cell
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    let row = tableView.selectedRow
    guard tools.indices.contains(row) else { return }
    onSelectionChange?(tools[row])
  }

  private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> ToolCellView {
    let cell = ToolCellView()
    cell.identifier = identifier

    let number = cell.numberLabel
    number.translatesAutoresizingMaskIntoConstraints = false
    number.alignment = .center
    number.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    number.textColor = .secondaryLabelColor
    cell.addSubview(number)

    let label = NSTextField(labelWithString: "")
    label.translatesAutoresizingMaskIntoConstraints = false
    label.lineBreakMode = .byTruncatingTail
    label.font = .systemFont(ofSize: NSFont.systemFontSize)
    cell.textField = label
    cell.addSubview(label)

    NSLayoutConstraint.activate([
      number.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
      number.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
      number.widthAnchor.constraint(equalToConstant: 18),

      label.leadingAnchor.constraint(equalTo: number.trailingAnchor, constant: 8),
      label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
      label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])

    return cell
  }
}
