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

    let header = NSTextField(labelWithString: tool.title)
    header.font = .systemFont(ofSize: 18, weight: .semibold)
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
      header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      header.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
      header.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),

      divider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      divider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
      divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
      divider.heightAnchor.constraint(equalToConstant: 1),

      placeholder.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
      placeholder.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
      placeholder.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
    ])

    self.view = container
  }
}
