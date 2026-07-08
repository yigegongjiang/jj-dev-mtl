import Cocoa

final class MainSplitViewController: NSSplitViewController {

  private let sidebar = SidebarViewController()
  private let detail = DetailContainerViewController()

  override func viewDidLoad() {
    super.viewDidLoad()

    splitView.dividerStyle = .thin

    let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebar)
    sidebarItem.minimumThickness = 200
    sidebarItem.maximumThickness = 320
    sidebarItem.canCollapse = true
    sidebarItem.holdingPriority = NSLayoutConstraint.Priority(260)
    addSplitViewItem(sidebarItem)

    let detailItem = NSSplitViewItem(viewController: detail)
    detailItem.minimumThickness = 480
    detailItem.canCollapse = false
    addSplitViewItem(detailItem)

    sidebar.onSelectionChange = { [weak self] tool in
      self?.detail.show(tool: tool)
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    sidebar.selectFirstIfNeeded()
  }
}
