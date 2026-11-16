import Foundation

/// Plain-file import and export so a world never depends on this application to be read.
extension WorkspaceStore {
  /// Imports a Markdown or text file as a draft document marked `imported`.
  /// The title is the first heading, otherwise the file name.
  public func importDocument(worldID: String, filename: String, text: String) throws -> LoreRecord {
    let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
    var lines = normalized.components(separatedBy: "\n")
    var title = (filename as NSString).deletingPathExtension
    if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
      lines[first].hasPrefix("#")
    {
      let heading = lines[first].drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
      if !heading.isEmpty {
        title = heading
        lines.removeSubrange(0...first)
      }
    }
    let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    guard body.count <= 200_000 else {
      throw SynthesisError.invalid("“\(filename)” is longer than 200,000 characters.")
    }
    return try createRecord(
      worldID: worldID,
      title: String(title.prefix(160)).isEmpty
        ? "Imported document"
        : String(
          title.prefix(160)), body: body, kind: "lore", origin: "imported")
  }
  /// Shared safe basename for a single export and the world's unique filenames.
  public static func markdownFilename(_ title: String) -> String {
    let cleaned = String(
      title.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "-" }
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
    return "\(cleaned.isEmpty ? "Untitled" : cleaned).md"
  }

  /// One portable document, including an entity's active sections as local anchors.
  public func exportRecordMarkdown(worldID: String, recordID: String) throws -> (
    filename: String, content: String
  ) {
    let record = try record(worldID: worldID, id: recordID)
    let sections = try recordSections(worldID: worldID, parentID: recordID)
    var content = try recordMarkdown(worldID: worldID, record: record)
    if !sections.isEmpty {
      content += "\n## Sections\n\n"
      content +=
        sections.map {
          "- [\(MarkdownText.escape($0.record.title))](#section-\($0.record.id)) · \($0.record.state)"
        }.joined(separator: "\n") + "\n"
      for section in sections {
        content += "\n<a id=\"section-\(section.record.id)\"></a>\n\n"
        content += try recordMarkdown(worldID: worldID, record: section.record, embedded: true)
      }
    }
    return (Self.markdownFilename(record.title), content)
  }

  private func recordMarkdown(worldID: String, record: LoreRecord, embedded: Bool = false) throws
    -> String
  {
    func json<T: Encodable>(_ value: T) -> String {
      String(decoding: (try? JSONEncoder().encode(value)) ?? Data(), as: UTF8.self)
    }
    let front = """
      ---
      id: \(record.id)
      kind: \(record.kind)
      category: \(json(record.category))
      state: \(record.state)
      origin: \(record.origin)
      version: \(record.version)
      updated: \(record.updatedAt)
      tags: \(json(record.tags ?? []))
      aliases: \(json(record.aliases ?? []))
      ---
      """
    let rules = record.kind == "entity" ? try rulesText(worldID: worldID, systemID: record.id) : ""
    let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let heading =
      "\(embedded ? "###" : "#") \(MarkdownText.escape(title.isEmpty ? "Untitled" : title))\n\n"
    let metadata =
      embedded
      ? "> \(record.state) · \(record.origin) · \(record.id)\n\n"
      : front + "\n\n"
    return metadata + heading + MarkdownText.body(record) + "\n"
      + (rules.isEmpty ? "" : "\n## Rules\n\n\(rules)\n")
  }

  /// One Markdown file per record with front matter, plus relationship and timeline indexes.
  /// Paths are relative; names are sanitised and made unique.
  public func exportMarkdown(worldID: String) throws -> [(path: String, content: String)] {
    let world = try world(worldID)
    let pages = try records(worldID: worldID)
    let titles = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0.title) })
    var used = Set<String>()
    func filename(_ title: String) -> String {
      let base = (Self.markdownFilename(title) as NSString).deletingPathExtension
      var name = base
      var counter = 2
      while !used.insert(name.lowercased()).inserted {
        name = "\(base) \(counter)"
        counter += 1
      }
      return name
    }
    var paths: [String: String] = [:]
    for record in pages {
      let folder: String
      switch record.kind {
      case "entity": folder = record.category.isEmpty ? "Entities" : record.category
      case "capture": folder = "Ideas"
      default: folder = "Documents"
      }
      // Categories are editable/imported text, never filesystem paths.
      let safeFolder = String(
        folder.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "-" }
      ).trimmingCharacters(in: .whitespaces)
      paths[record.id] =
        "\(safeFolder.isEmpty ? "Records" : safeFolder)/\(filename(record.title)).md"
    }
    func markdownLabel(_ title: String) -> String {
      title.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "[", with: "\\[")
        .replacingOccurrences(of: "]", with: "\\]")
        .replacingOccurrences(of: "\n", with: " ")
    }
    var files: [(String, String)] = []
    for record in pages {
      let sections = try recordSections(worldID: worldID, parentID: record.id)
      let sectionIndex =
        sections.isEmpty
        ? ""
        : "\n## Sections\n\n"
          + sections.map {
            let relative = "../" + (paths[$0.record.id] ?? "")
            let url =
              relative.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relative
            return "- [\(markdownLabel($0.record.title))](\(url)) · \($0.record.state)"
          }.joined(separator: "\n") + "\n"
      files.append(
        (
          paths[record.id]!,
          try recordMarkdown(worldID: worldID, record: record) + sectionIndex
        )
      )
    }
    let related = try relations(worldID: worldID).map {
      "- \(titles[$0.sourceID] ?? $0.sourceID) — \($0.label) → \(titles[$0.targetID] ?? $0.targetID)"
    }
    files.append(
      (
        "Relationships.md",
        "# Relationships\n\nDraft relationships between entities in \(world.name).\n\n"
          + (related.isEmpty ? "None yet.\n" : related.joined(separator: "\n") + "\n")
      ))
    let history = try events(worldID: worldID).map {
      "- **\($0.dateLabel == "unknown" ? "Date unknown" : $0.dateLabel)** — \($0.title) (source: \(titles[$0.sourceID] ?? "archived record"))"
    }
    files.append(
      (
        "Timeline.md",
        "# Timeline\n\n"
          + (history.isEmpty ? "None yet.\n" : history.joined(separator: "\n") + "\n")
      ))
    files.append(
      (
        "README.md",
        "# \(world.name)\n\nExported from Synthesis on \(timestamp()). \(pages.count) records. Draft and canon states are in each file's front matter; archived material is in the JSON export only.\n"
      ))
    return files.map { (path: $0.0, content: $0.1) }
  }
}
