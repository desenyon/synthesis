import AppKit
import Foundation

/// Preserves the native editor's headings, emphasis, underline and links in portable Markdown.
/// Plain Markdown/imported documents are already source text and pass through unchanged.
enum MarkdownText {
  static func escape(_ text: String) -> String {
    text.reduce(into: "") { result, character in
      if "\\`*_[]<>#".contains(character) { result += "\\" }
      result.append(character)
    }
  }
  static func richBody(_ body: String, rtf: String?) -> NSAttributedString? {
    guard let rtf, let data = Data(base64Encoded: rtf),
      let rich = NSAttributedString(rtf: data, documentAttributes: nil), rich.string == body
    else { return nil }
    return rich
  }

  /// Inspect native link ranges without exporting rich text or unrelated URLs.
  static func assistantBody(
    _ body: String, rtf: String, replacement: (URL?) -> String?
  ) -> String? {
    guard let rich = richBody(body, rtf: rtf), rich.string.utf8.elementsEqual(body.utf8) else {
      return nil
    }
    var replacements: [(NSRange, String)] = []
    rich.enumerateAttribute(.link, in: NSRange(location: 0, length: rich.length)) {
      value, range, _ in
      guard let value else { return }
      let raw = (value as? URL)?.absoluteString ?? (value as? String)
      if let raw, !raw.lowercased().hasPrefix("synthesis:") { return }
      if let safe = replacement(raw.flatMap { URL(string: $0) }) {
        replacements.append((range, safe))
      }
    }
    let result = NSMutableString(string: body)
    for (range, text) in replacements.reversed() { result.replaceCharacters(in: range, with: text) }
    return result as String
  }

  static func body(_ record: LoreRecord) -> String {
    guard let rich = richBody(record.body, rtf: record.rtf) else { return record.body }
    let text = rich.string as NSString
    var paragraphs: [String] = []
    var offset = 0
    while offset < text.length {
      let whole = text.paragraphRange(for: NSRange(location: offset, length: 0))
      offset = NSMaxRange(whole)
      var range = whole
      while range.length > 0 && [10, 13].contains(text.character(at: NSMaxRange(range) - 1)) {
        range.length -= 1
      }
      guard range.length > 0 else {
        paragraphs.append("")
        continue
      }
      let font = rich.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
      let heading =
        (font?.pointSize ?? 16) >= 22 ? "## " : ((font?.pointSize ?? 16) >= 18 ? "### " : "")
      var paragraph = ""
      rich.enumerateAttributes(in: range) { attributes, run, _ in
        let raw = text.substring(with: run)
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
          paragraph += raw
          return
        }
        let leading = String(raw.prefix(while: { $0.isWhitespace }))
        let trailing = String(raw.reversed().prefix(while: { $0.isWhitespace }).reversed())
        var value = escape(trimmed)
        let traits = (attributes[.font] as? NSFont)?.fontDescriptor.symbolicTraits ?? []
        if traits.contains(.italic) { value = "*\(value)*" }
        if traits.contains(.bold) && heading.isEmpty { value = "**\(value)**" }
        if let underline = attributes[.underlineStyle] as? NSNumber, underline.intValue != 0 {
          value = "<u>\(value)</u>"
        }
        if let link = attributes[.link] {
          let url = (link as? URL)?.absoluteString ?? (link as? String) ?? ""
          if !url.isEmpty {
            let safe = url.replacingOccurrences(of: ")", with: "%29")
              .replacingOccurrences(of: "(", with: "%28").replacingOccurrences(of: " ", with: "%20")
              .replacingOccurrences(of: "\n", with: "%0A")
            value = "[\(value)](\(safe))"
          }
        }
        paragraph += leading + value + trailing
      }
      paragraphs.append(heading + paragraph)
    }
    return paragraphs.joined(separator: "\n\n")
  }
}
