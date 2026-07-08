import Cocoa

final class MainSplitViewController: NSSplitViewController {

  private let sidebar = SidebarViewController()
  private let detail = DetailContainerViewController()
  private var keyMonitor: Any?

  override func viewDidLoad() {
    super.viewDidLoad()

    splitView.dividerStyle = .thin

    let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
    sidebarItem.minimumThickness = 150
    sidebarItem.maximumThickness = 220
    sidebarItem.canCollapse = true
    sidebarItem.holdingPriority = NSLayoutConstraint.Priority(260)
    addSplitViewItem(sidebarItem)

    let detailItem = NSSplitViewItem(viewController: detail)
    detailItem.minimumThickness = 380
    detailItem.canCollapse = false
    addSplitViewItem(detailItem)

    sidebar.onSelectionChange = { [weak self] tool in
      self?.detail.show(tool: tool)
    }

    sidebarItem.isCollapsed = true  // 默认折叠: 功能少 + 数字键可切换, 空间尽量留给输入输出
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    sidebar.selectFirstIfNeeded()
    if keyMonitor == nil {
      keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        self?.handleDigitKey(event) ?? event
      }
    }
  }

  deinit {
    if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
  }

  // 非输入框聚焦时, 数字键 1-9 选中对应工具
  private func handleDigitKey(_ event: NSEvent) -> NSEvent? {
    guard event.window === view.window,
      event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
      let chars = event.charactersIgnoringModifiers, chars.count == 1,
      let n = Int(chars), n >= 1, n <= sidebar.toolCount
    else { return event }
    // 正在编辑文本 -> 放行, 让数字进入输入框
    if let tv = view.window?.firstResponder as? NSTextView, tv.isEditable {
      return event
    }
    sidebar.selectTool(at: n - 1)
    return nil
  }
}
