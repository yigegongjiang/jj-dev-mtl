import Cocoa

struct Tool {
  let id: String
  let title: String
}

enum ToolCatalog {
  static let all: [Tool] = [
    Tool(id: "json-formatter", title: "Format JSON"),
    Tool(id: "text-escape-unescape", title: "Multiline ⇄ Singleline"),
    Tool(id: "base64", title: "Base64 Encoder / Decoder"),
    Tool(id: "url-codec", title: "URL Encoder / Decoder"),
    Tool(id: "hash", title: "Hash Generator"),
    Tool(id: "uuid", title: "UUID Generator"),
    Tool(id: "timestamp", title: "Unix Timestamp"),
    Tool(id: "regex", title: "Regex Tester"),
    Tool(id: "diff", title: "Text Diff"),
    Tool(id: "settings", title: "Settings"),
  ]
}
