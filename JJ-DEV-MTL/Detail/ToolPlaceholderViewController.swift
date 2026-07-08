import Cocoa

final class ToolPlaceholderViewController: NSViewController {

  private let tool: Tool

  init(tool: Tool) {
    self.tool = tool
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError() }

  override func loadView() {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let icon = NSImageView()
    icon.translatesAutoresizingMaskIntoConstraints = false
    icon.image = NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: nil)
    icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
    icon.contentTintColor = .secondaryLabelColor

    let title = NSTextField(labelWithString: tool.title)
    title.font = .systemFont(ofSize: 22, weight: .semibold)

    let header = NSStackView(views: [icon, title])
    header.orientation = .horizontal
    header.spacing = 10
    header.alignment = .centerY
    header.translatesAutoresizingMaskIntoConstraints = false

    let divider = NSBox()
    divider.boxType = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false

    let placeholder = NSTextField(labelWithString: "TODO: \(tool.title) 内容占位")
    placeholder.font = .systemFont(ofSize: 14)
    placeholder.textColor = .secondaryLabelColor
    placeholder.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(header)
    container.addSubview(divider)
    container.addSubview(placeholder)

    NSLayoutConstraint.activate([
      header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
      header.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
      header.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),

      divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
      divider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
      divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
      divider.heightAnchor.constraint(equalToConstant: 1),

      placeholder.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
      placeholder.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
      placeholder.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 24),
    ])

    self.view = container
  }
}
