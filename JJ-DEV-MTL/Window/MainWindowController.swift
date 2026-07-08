import Cocoa

final class MainWindowController: NSWindowController, NSWindowDelegate {

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "JJ-DEV-MTL"
    window.titlebarAppearsTransparent = false
    window.minSize = NSSize(width: 720, height: 460)
    window.center()
    window.setFrameAutosaveName("JJDEVMTL.MainWindow")

    let split = MainSplitViewController()
    window.contentViewController = split

    self.init(window: window)
    window.delegate = self
  }
}
