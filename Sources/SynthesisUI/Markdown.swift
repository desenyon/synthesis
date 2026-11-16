import SwiftUI

/// Block-level Markdown used for model answers. Parsing is pure so it can be tested directly.
enum MarkdownBlock: Equatable {
  case heading(level: Int, text: String)
  case paragraph(String)
  case list(ordered: Bool, items: [ListItem])
  case quote(String)
  case code(String)
  case table([[String]])
  case rule
  struct ListItem: Equatable {
    var indent: Int
    var marker: String
    var text: String
  }

  static func parse(_ source: String) -> [MarkdownBlock] {
    var blocks: [MarkdownBlock] = []
    var paragraph: [String] = []
    let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
    var i = 0
    func flush() {
      if !paragraph.isEmpty {
        blocks.append(.paragraph(paragraph.joined(separator: "\n")))
        paragraph = []
      }
    }
    while i < lines.count {
      let line = lines[i]
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("```") {
        flush()
        var code: [String] = []
        i += 1
        while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
          code.append(lines[i])
          i += 1
        }
        blocks.append(.code(code.joined(separator: "\n")))
        i += 1
        continue
      }
      if trimmed.isEmpty {
        flush()
        i += 1
        continue
      }
      if let heading = headingLine(trimmed) {
        flush()
        blocks.append(heading)
        i += 1
        continue
      }
      if trimmed.count >= 3, Set(trimmed).isSubset(of: ["-", "*", "_", " "]),
        trimmed.filter({ $0 != " " }).count >= 3, Set(trimmed.filter { $0 != " " }).count == 1
      {
        flush()
        blocks.append(.rule)
        i += 1
        continue
      }
      if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableDivider(lines[i + 1]) {
        flush()
        var rows = [cells(trimmed)]
        i += 2
        while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
          rows.append(cells(lines[i]))
          i += 1
        }
        blocks.append(.table(rows))
        continue
      }
      if trimmed.hasPrefix(">") {
        flush()
        var quoted: [String] = []
        while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
          quoted.append(
            String(lines[i].trimmingCharacters(in: .whitespaces).dropFirst())
              .trimmingCharacters(in: .whitespaces))
          i += 1
        }
        blocks.append(.quote(quoted.joined(separator: "\n")))
        continue
      }
      if let first = listItem(line) {
        flush()
        var items = [first]
        let ordered = first.marker != "•"
        i += 1
        while i < lines.count {
          if let next = listItem(lines[i]) {
            items.append(next)
            i += 1
          } else if !lines[i].trimmingCharacters(in: .whitespaces).isEmpty,
            lines[i].hasPrefix("  "), !items.isEmpty
          {
            // A wrapped continuation line belongs to the previous item.
            items[items.count - 1].text += " " + lines[i].trimmingCharacters(in: .whitespaces)
            i += 1
          } else {
            break
          }
        }
        blocks.append(.list(ordered: ordered, items: items))
        continue
      }
      paragraph.append(trimmed)
      i += 1
    }
    flush()
    return blocks
  }
  private static func headingLine(_ line: String) -> MarkdownBlock? {
    let hashes = line.prefix { $0 == "#" }.count
    guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
    return .heading(
      level: hashes, text: line.dropFirst(hashes).trimmingCharacters(in: .whitespaces))
  }
  private static func isTableDivider(_ line: String) -> Bool {
    let value = line.trimmingCharacters(in: .whitespaces)
    return value.contains("-") && value.contains("|")
      && value.allSatisfy { "|:- ".contains($0) }
  }
  private static func cells(_ line: String) -> [String] {
    var value = line.trimmingCharacters(in: .whitespaces)
    if value.hasPrefix("|") { value.removeFirst() }
    if value.hasSuffix("|") { value.removeLast() }
    return value.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
  }
  private static func listItem(_ line: String) -> ListItem? {
    let indent = line.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 2 : 1) } / 2
    let body = line.trimmingCharacters(in: .whitespaces)
    for bullet in ["- ", "* ", "+ "] where body.hasPrefix(bullet) {
      return ListItem(indent: indent, marker: "•", text: String(body.dropFirst(2)))
    }
    let digits = body.prefix { $0.isNumber }
    if !digits.isEmpty, digits.count <= 3 {
      let rest = body.dropFirst(digits.count)
      if rest.hasPrefix(". ") || rest.hasPrefix(") ") {
        return ListItem(
          indent: indent, marker: String(digits) + ".", text: String(rest.dropFirst(2)))
      }
    }
    return nil
  }
}

struct MarkdownContent: View {
  let text: String
  let t: Theme
  var size: CGFloat = 15
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
        view(block)
      }
    }.foregroundStyle(t.text).tint(t.accent)
  }
  @ViewBuilder private func view(_ block: MarkdownBlock) -> some View {
    switch block {
    case .heading(let level, let text):
      Text(inline(text)).font(
        .system(size: level == 1 ? size + 6 : level == 2 ? size + 3 : size + 1, weight: .semibold)
      ).padding(.top, level <= 2 ? 6 : 2).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
    case .paragraph(let text):
      Text(inline(text)).font(.studio(size: size)).lineSpacing(5).textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    case .list(_, let items):
      VStack(alignment: .leading, spacing: 6) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(item.marker).font(.studio(size: size)).monospacedDigit()
              .foregroundStyle(t.muted).frame(minWidth: 14, alignment: .trailing)
            Text(inline(item.text)).font(.studio(size: size)).lineSpacing(5)
              .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
          }.padding(.leading, CGFloat(item.indent) * 18)
        }
      }
    case .quote(let text):
      HStack(alignment: .top, spacing: 12) {
        RoundedRectangle(cornerRadius: 1.5).fill(t.accent.opacity(0.6)).frame(width: 3)
        Text(inline(text)).font(.studio(size: size)).lineSpacing(5)
          .foregroundStyle(t.secondary).textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }.fixedSize(horizontal: false, vertical: true)
    case .code(let code):
      ScrollView(.horizontal) {
        Text(code).font(.studio(size: size - 2, design: .monospaced)).lineSpacing(3)
          .textSelection(.enabled).padding(14)
      }.frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hairline, lineWidth: 1))
    case .table(let rows):
      table(rows)
    case .rule:
      Rectangle().fill(t.hairline).frame(height: 1).padding(.vertical, 4)
    }
  }
  private func table(_ rows: [[String]]) -> some View {
    let columns = rows.map(\.count).max() ?? 0
    return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        GridRow {
          ForEach(0..<columns, id: \.self) { column in
            Text(inline(column < row.count ? row[column] : ""))
              .font(.studio(size: size - 1, weight: index == 0 ? .semibold : .regular))
              .foregroundStyle(index == 0 ? t.secondary : t.text).textSelection(.enabled)
              .lineSpacing(3).padding(.horizontal, 14).padding(.vertical, 9)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }.background(index == 0 ? t.surface : .clear)
        if index < rows.count - 1 {
          Rectangle().fill(t.hairline).frame(height: 1).gridCellUnsizedAxes(.horizontal)
        }
      }
    }.clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hairline, lineWidth: 1))
      .fixedSize(horizontal: false, vertical: true)
  }
  private func inline(_ value: String) -> AttributedString {
    (try? AttributedString(
      markdown: value, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
      ?? AttributedString(value)
  }
}
