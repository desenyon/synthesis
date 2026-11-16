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
  /// One Markdown file per record with front matter, plus relationship and timeline indexes.
  /// Paths are relative; names are sanitised and made unique.
  public func exportMarkdown(worldID: String) throws -> [(path: String, content: String)] {
    let world = try world(worldID)
    let pages = try records(worldID: worldID)
    let titles = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0.title) })
    var used = Set<String>()
    func filename(_ title: String) -> String {
      let cleaned = title.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "-" }
      var base = String(cleaned).trimmingCharacters(in: .whitespaces)
      if base.isEmpty { base = "untitled" }
      var name = base
      var counter = 2
      while !used.insert(name.lowercased()).inserted {
        name = "\(base) \(counter)"
        counter += 1
      }
      return name
    }
    func list(_ values: [String]?) -> String {
      "["
        + (values ?? []).map { "\"\($0.replacingOccurrences(of: "\"", with: "'"))\"" }.joined(
          separator: ", ") + "]"
    }
    var files: [(String, String)] = []
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
      let front = """
        ---
        id: \(record.id)
        kind: \(record.kind)
        category: "\(record.category)"
        state: \(record.state)
        origin: \(record.origin)
        version: \(record.version)
        updated: \(record.updatedAt)
        tags: \(list(record.tags))
        aliases: \(list(record.aliases))
        ---
        """
      let rules =
        record.kind == "entity" ? try rulesText(worldID: worldID, systemID: record.id) : ""
      files.append(
        (
          "\(safeFolder.isEmpty ? "Records" : safeFolder)/\(filename(record.title)).md",
          "\(front)\n\n# \(record.title)\n\n\(record.body)\n"
            + (rules.isEmpty ? "" : "\n## Rules\n\n\(rules)\n")
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
