import Cocoa

// text-utils 工具共享 UI: 标题 + 方向切换按钮 + (可选)工具级附加控件 + 可拖拽 split (输入/结果) + 错误提示.
// 无 Input/Result 标签, 无 Copy/Paste 按钮 (面向键盘用户: 结果可选中直接 ⌘C); 出现时自动探查剪贴板填入输入.
class TextUtilsViewController: NSViewController, NSTextViewDelegate, NSSplitViewDelegate {

  private let tool: Tool
  private let placeholder: String
  private let resultDefaultText: String

  private var inputTextView: NSTextView!
  private var resultTextView: NSTextView!

  private var ioSplit: IOSplitView!
  private var orientationButton: NSButton!
  private var didLayoutOnce = false
  private var didAutofill = false

  static let resultFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
  private static let orientationKey = "JJDEVMTL.IOSplit.vertical"  // true = 左右, false = 上下
  private static let minPaneSize: CGFloat = 120

  init(tool: Tool, placeholder: String, resultDefaultText: String) {
    self.tool = tool
    self.placeholder = placeholder
    self.resultDefaultText = resultDefaultText
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError() }

  // 子类实现: 输入 -> (结果, 错误)
  func transform(_ input: String) -> (result: String, error: String?) {
    return ("", nil)
  }

  // 子类覆盖: 结果染色; 默认纯文本
  func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    SyntaxHighlighter.plain(result, font: font)
  }

  // 子类覆盖: 标题栏下方的工具级附加控件 (如方向切换); 默认无
  func makeAccessory() -> NSView? { nil }

  // 供子类在附加控件变化后刷新结果
  func reloadResult() { refresh() }

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    orientationButton = NSButton(title: "", target: self, action: #selector(toggleOrientation))
    orientationButton.bezelStyle = .texturedRounded
    orientationButton.imagePosition = .imageOnly
    orientationButton.translatesAutoresizingMaskIntoConstraints = false
    orientationButton.setContentHuggingPriority(.required, for: .horizontal)

    // 输入 / 结果: 无标签, 滚动文本区直接入 split
    let inputScroll = Self.makeScrollableTextView(editable: true, placeholder: placeholder)
    inputTextView = inputScroll.documentView as? NSTextView
    inputTextView.delegate = self
    // 恢复上次内容; 无则主动填入剪贴板 (在 loadView 中执行, 不依赖 appearance 时序)
    if let saved = UserDefaults.standard.string(forKey: inputStorageKey), !saved.isEmpty {
      inputTextView.string = saved
    } else if let clip = NSPasteboard.general.string(forType: .string),
      !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      inputTextView.string = clip
    }

    let resultScroll = Self.makeScrollableTextView(editable: false, placeholder: nil)
    resultTextView = resultScroll.documentView as? NSTextView
    resultTextView.isRichText = true       // 承载语法染色
    resultTextView.isSelectable = true     // 键盘用户直接 ⌘C 复制

    ioSplit = IOSplitView()
    ioSplit.translatesAutoresizingMaskIntoConstraints = false
    ioSplit.isVertical = UserDefaults.standard.bool(forKey: Self.orientationKey)
    ioSplit.delegate = self
    ioSplit.onDividerDoubleClick = { [weak self] in self?.centerDivider() }
    ioSplit.addArrangedSubview(Self.makePane(inputScroll))
    ioSplit.addArrangedSubview(Self.makePane(resultScroll))
    updateOrientationButton()

    let accessory = makeAccessory()
    accessory?.translatesAutoresizingMaskIntoConstraints = false

    var subviews: [NSView] = [orientationButton, ioSplit]
    if let accessory { subviews.append(accessory) }
    for v in subviews { container.addSubview(v) }

    // 顶部单行控制条: (可选)方向段控在左 + 布局切换按钮在右; 无冗余标题(侧栏已标识), 无分隔行
    NSLayoutConstraint.activate([
      orientationButton.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 6),
      orientationButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

      ioSplit.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      ioSplit.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      ioSplit.topAnchor.constraint(equalTo: orientationButton.bottomAnchor, constant: 8),
      ioSplit.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
    ])

    if let accessory {
      NSLayoutConstraint.activate([
        accessory.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        accessory.centerYAnchor.constraint(equalTo: orientationButton.centerYAnchor),
        accessory.trailingAnchor.constraint(lessThanOrEqualTo: orientationButton.leadingAnchor, constant: -12),
      ])
    }

    self.view = container
    refresh()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    if !didLayoutOnce, ioSplit.bounds.width > 0, ioSplit.bounds.height > 0 {
      didLayoutOnce = true
      centerDivider()
    }
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    // 不自动聚焦输入框: 保证非编辑态下数字键可直接选工具; 需编辑时点击输入框即可
    autofillFromClipboard()
  }

  // 主动探查剪贴板: 首次出现且输入为空时, 有字符串则自动填入
  private func autofillFromClipboard() {
    guard !didAutofill else { return }
    didAutofill = true
    guard inputTextView.string.isEmpty,
      let clip = NSPasteboard.general.string(forType: .string),
      !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    inputTextView.string = clip
    refresh()
  }

  // MARK: - 方向切换

  @objc private func toggleOrientation() {
    ioSplit.isVertical.toggle()
    UserDefaults.standard.set(ioSplit.isVertical, forKey: Self.orientationKey)
    updateOrientationButton()
    ioSplit.adjustSubviews()
    ioSplit.layoutSubtreeIfNeeded()
    centerDivider()
  }

  private func updateOrientationButton() {
    let symbol = ioSplit.isVertical ? "rectangle.split.1x2" : "rectangle.split.2x1"
    orientationButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle layout")
    orientationButton.toolTip = ioSplit.isVertical ? "Switch to stacked layout" : "Switch to side-by-side layout"
  }

  private func centerDivider() {
    let total = ioSplit.isVertical ? ioSplit.bounds.width : ioSplit.bounds.height
    guard total > 0 else { return }
    ioSplit.setPosition((total - ioSplit.dividerThickness) / 2, ofDividerAt: 0)
  }

  // MARK: - NSSplitViewDelegate (限制两侧 pane 最小尺寸)

  func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMin: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
    proposedMin + Self.minPaneSize
  }

  func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMax: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
    proposedMax - Self.minPaneSize
  }

  // MARK: - 数据流

  private var inputStorageKey: String { "JJDEVMTL.input.\(tool.id)" }

  func textDidChange(_ notification: Notification) {
    UserDefaults.standard.set(inputTextView.string, forKey: inputStorageKey)  // 持久化最新内容
    refresh()
  }

  private func refresh() {
    let input = inputTextView?.string ?? ""
    if input.isEmpty {
      setResult(NSAttributedString(string: resultDefaultText, attributes: [
        .font: Self.resultFont, .foregroundColor: NSColor.secondaryLabelColor,
      ]))
      return
    }
    let (result, error) = transform(input)
    if let error {
      // 错误直接显示在结果区 (不占常驻行)
      setResult(NSAttributedString(string: error, attributes: [
        .font: Self.resultFont, .foregroundColor: NSColor.systemRed,
      ]))
    } else {
      setResult(highlightResult(result, font: Self.resultFont))
    }
  }

  private func setResult(_ attr: NSAttributedString) {
    resultTextView.textStorage?.setAttributedString(attr)
  }

  // MARK: - 构件

  // 一个 pane: 滚动文本区填满 (无标签)
  private static func makePane(_ scroll: NSView) -> NSView {
    let pane = NSView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    pane.addSubview(scroll)
    NSLayoutConstraint.activate([
      scroll.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
      scroll.topAnchor.constraint(equalTo: pane.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
    ])
    return pane
  }

  private static func makeScrollableTextView(editable: Bool, placeholder: String?) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.hasVerticalScroller = true
    scroll.hasHorizontalScroller = false
    scroll.autohidesScrollers = true
    scroll.borderType = .lineBorder
    scroll.drawsBackground = true

    let tv = NSTextView()
    tv.isEditable = editable
    tv.isRichText = false
    tv.allowsUndo = editable
    tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    tv.autoresizingMask = [.width]
    tv.isVerticallyResizable = true
    tv.isHorizontallyResizable = false
    tv.textContainerInset = NSSize(width: 6, height: 6)
    tv.textContainer?.widthTracksTextView = true
    tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    tv.minSize = NSSize(width: 0, height: 0)
    tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    if let placeholder {
      tv.setValue(NSAttributedString(string: placeholder, attributes: [
        .foregroundColor: NSColor.tertiaryLabelColor,
        .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
      ]), forKey: "placeholderAttributedString")
    }
    scroll.documentView = tv
    return scroll
  }
}

// 互反工具合一: 单个小图标按钮翻转 多行→单行 / 单行→多行 (方向持久化)
final class EscapeUnescapeViewController: TextUtilsViewController {

  private var isUnescape = UserDefaults.standard.bool(forKey: "JJDEVMTL.escape.unescape")
  private var dirButton: NSButton!

  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste or type text here...",
      resultDefaultText: "Enter text above to see the result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }

  override func makeAccessory() -> NSView? {
    let b = NSButton(title: "", target: self, action: #selector(toggleDirection))
    b.bezelStyle = .texturedRounded
    b.imagePosition = .imageOnly
    b.translatesAutoresizingMaskIntoConstraints = false
    b.setContentHuggingPriority(.required, for: .horizontal)
    dirButton = b
    updateDirButton()
    return b
  }

  @objc private func toggleDirection() {
    isUnescape.toggle()
    UserDefaults.standard.set(isUnescape, forKey: "JJDEVMTL.escape.unescape")
    updateDirButton()
    reloadResult()
  }

  private func updateDirButton() {
    let symbol = isUnescape ? "arrow.left.to.line" : "arrow.right.to.line"
    dirButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Toggle direction")
    dirButton.toolTip = isUnescape
      ? "Singleline → Multiline (click to switch)"
      : "Multiline → Singleline (click to switch)"
  }

  override func transform(_ input: String) -> (result: String, error: String?) {
    isUnescape
      ? (TextUtilsCore.unescapeToMultiline(input), nil)
      : (TextUtilsCore.escapeToSingleline(input), nil)
  }

  override func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    isUnescape
      ? SyntaxHighlighter.plain(result, font: font)
      : SyntaxHighlighter.escaped(result, font: font)
  }
}

final class FormatJsonViewController: TextUtilsViewController {
  init(tool: Tool) {
    super.init(
      tool: tool,
      placeholder: "Paste JSON or escaped JSON string (e.g. {\"k\":\"v\"} or \"{\\\"k\\\":\\\"v\\\"}\")...",
      resultDefaultText: "Enter JSON above to see the formatted result"
    )
  }
  required init?(coder: NSCoder) { fatalError() }
  override func transform(_ input: String) -> (result: String, error: String?) {
    let r = TextUtilsCore.formatJson(input)
    return (r.result, r.error)
  }
  override func highlightResult(_ result: String, font: NSFont) -> NSAttributedString {
    SyntaxHighlighter.json(result, font: font)
  }
}
