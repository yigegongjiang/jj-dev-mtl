import Foundation

// 纯逻辑, module 默认 MainActor 隔离 -> 显式 nonisolated 便于单元测试从任意线程调用
enum TextUtilsCore {

  // 多行 -> 单行: 反斜杠 / 双引号 / CRLF / LF / CR / TAB 转义, 外裹双引号
  nonisolated static func escapeToSingleline(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count + 2)
    for ch in text {
      switch ch {
      case "\\": out += "\\\\"
      case "\"": out += "\\\""
      case "\r\n": out += "\\n"
      case "\n": out += "\\n"
      case "\r": out += "\\r"
      case "\t": out += "\\t"
      default: out.append(ch)
      }
    }
    return "\"\(out)\""
  }

  // 单行 -> 多行: \n \t \r \\ 反转义; 其余 \X 保留原样 (与源 JS 实现一致)
  nonisolated static func unescapeToMultiline(_ text: String) -> String {
    var out = ""
    out.reserveCapacity(text.count)
    let chars = Array(text)
    var i = 0
    while i < chars.count {
      if chars[i] == "\\", i + 1 < chars.count {
        switch chars[i + 1] {
        case "n": out.append("\n"); i += 2
        case "t": out.append("\t"); i += 2
        case "r": out.append("\r"); i += 2
        case "\\": out.append("\\"); i += 2
        default: out.append(chars[i]); i += 1
        }
      } else {
        out.append(chars[i]); i += 1
      }
    }
    return out
  }

  struct FormatResult {
    let result: String
    let error: String?
  }

  // JSON 格式化 + 嵌套解包 + 主动探查含噪输入.
  // 输入不可信, 预期值可能被前后冗余包裹, 逐级降级探查:
  //   1. 直接解析
  //   2. 整体是被转义的 JSON 串 ("{\"k\":\"v\"}")
  //   3. 从含噪文本中取最长可解析的平衡 JSON 区段 (日志前后缀 / markdown 围栏 / JSONP / 赋值等)
  //   4. 探查区段本身仍是被转义的
  nonisolated static func formatJson(_ text: String) -> FormatResult {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return FormatResult(result: "", error: "Empty input")
    }

    var firstError: String?
    func attempt(_ s: String) -> String? {
      do {
        return try serialize(parseAndUnwrap(s))
      } catch {
        if firstError == nil { firstError = (error as NSError).localizedDescription }
        return nil
      }
    }

    // 逐层构造候选: 原文 + 逐次 JSON 反转义 (\" \\ \n … , 应对被转义 / 多重转义)
    var variants = [trimmed]
    var cur = trimmed
    for _ in 0..<4 {
      let de = jsonUnescape(cur)
      if de == cur { break }
      variants.append(de)
      cur = de
    }

    // 每个候选: 先整体解析, 再从含噪文本抽取最长平衡 JSON 区段 (转义与噪声叠加也能命中)
    for v in variants {
      if let out = attempt(v) { return FormatResult(result: out, error: nil) }
      if let cand = probeLongestJSON(in: v), let out = attempt(cand) {
        return FormatResult(result: out, error: nil)
      }
    }

    // 兜底: 整体是待包裹的转义 JSON 串
    if trimmed.contains("\\\""), let out = attempt("\"\(trimmed)\"") {
      return FormatResult(result: out, error: nil)
    }

    return FormatResult(result: "", error: firstError ?? "Invalid JSON")
  }

  // JSON 字符串反转义: 把 \" \\ \/ \n \t \r \b \f \uXXXX 还原, 未知转义保留反斜杠
  private nonisolated static func jsonUnescape(_ s: String) -> String {
    guard s.contains("\\") else { return s }
    var out = ""
    out.reserveCapacity(s.count)
    let a = Array(s)
    let n = a.count
    var i = 0
    while i < n {
      guard a[i] == "\\", i + 1 < n else { out.append(a[i]); i += 1; continue }
      switch a[i + 1] {
      case "\"": out.append("\""); i += 2
      case "\\": out.append("\\"); i += 2
      case "/": out.append("/"); i += 2
      case "n": out.append("\n"); i += 2
      case "t": out.append("\t"); i += 2
      case "r": out.append("\r"); i += 2
      case "b": out.append("\u{08}"); i += 2
      case "f": out.append("\u{0C}"); i += 2
      case "u" where i + 5 < n:
        if let code = UInt32(String(a[(i + 2)...(i + 5)]), radix: 16), let scalar = Unicode.Scalar(code) {
          out.append(Character(scalar)); i += 6
        } else { out.append(a[i]); i += 1 }
      default: out.append(a[i]); i += 1
      }
    }
    return out
  }

  // 平衡括号扫描: 收集所有可独立解析的顶层 { } / [ ] 区段, 返回最长者 (最可能是预期载荷)
  private nonisolated static func probeLongestJSON(in raw: String) -> String? {
    let chars = Array(raw)
    let n = chars.count
    var best: String?
    var i = 0
    while i < n {
      let c = chars[i]
      if c == "{" || c == "[", let end = matchBalanced(chars, from: i) {
        let region = String(chars[i...end])
        if (try? JSONSerialization.jsonObject(with: Data(region.utf8), options: [.fragmentsAllowed])) != nil {
          if best == nil || region.count > best!.count { best = region }
        }
        i = end + 1
        continue
      }
      i += 1
    }
    return best
  }

  // 从 start 处的开括号找到配平的闭括号下标; 正确跳过字符串字面量与其中的转义
  private nonisolated static func matchBalanced(_ chars: [Character], from start: Int) -> Int? {
    var depth = 0
    var inString = false
    var i = start
    let n = chars.count
    while i < n {
      let c = chars[i]
      if inString {
        if c == "\\" { i += 2; continue }  // 跳过被转义字符
        if c == "\"" { inString = false }
        i += 1
        continue
      }
      switch c {
      case "\"": inString = true
      case "{", "[": depth += 1
      case "}", "]":
        depth -= 1
        if depth == 0 { return i }
        if depth < 0 { return nil }
      default: break
      }
      i += 1
    }
    return nil
  }

  private nonisolated static func parseAndUnwrap(_ s: String) throws -> Any {
    guard let data = s.data(using: .utf8) else {
      throw NSError(domain: "TextUtilsCore", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
    }
    let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    return unwrapNested(obj, depth: 0)
  }

  private nonisolated static func unwrapNested(_ value: Any, depth: Int) -> Any {
    if depth > 20 { return value }
    if let s = value as? String {
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.hasPrefix("{") || t.hasPrefix("[") {
        if let data = t.data(using: .utf8),
          let parsed = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
          return unwrapNested(parsed, depth: depth + 1)
        }
      }
      return s
    }
    if let arr = value as? [Any] {
      return arr.map { unwrapNested($0, depth: depth + 1) }
    }
    if let dict = value as? [String: Any] {
      var out: [String: Any] = [:]
      for (k, v) in dict { out[k] = unwrapNested(v, depth: depth + 1) }
      return out
    }
    return value
  }

  private nonisolated static func serialize(_ value: Any) throws -> String {
    let opts: JSONSerialization.WritingOptions = [
      .prettyPrinted, .sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed,
    ]
    let data = try JSONSerialization.data(withJSONObject: value, options: opts)
    guard let s = String(data: data, encoding: .utf8) else {
      throw NSError(domain: "TextUtilsCore", code: -2,
        userInfo: [NSLocalizedDescriptionKey: "UTF-8 decode failed"])
    }
    // JSONSerialization prettyPrinted 默认 2 空格缩进, 无需替换
    return s
  }
}
