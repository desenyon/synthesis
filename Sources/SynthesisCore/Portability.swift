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
    let artwork =
      record.kind == "entity" ? try recordArtwork(worldID: worldID, recordID: record.id) : nil
    let illustration =
      artwork.map {
        "![\(MarkdownText.escape(record.title)) artwork](data:\($0.mimeType);base64,\($0.image))\n\n> Visual reference · \($0.origin)\n\n"
      } ?? ""
    let properties = try entityPropertyText(worldID: worldID, recordID: record.id, limit: 8_000_000)
    let names =
      record.kind == "entity" ? try entityNamePeriods(worldID: worldID, recordID: record.id) : []
    let nameHistory = names.map { period in
      let start = period.startLabel.isEmpty ? "Unknown" : MarkdownText.escape(period.startLabel)
      let end = period.endLabel.isEmpty ? "Unknown" : MarkdownText.escape(period.endLabel)
      return
        "- \(period.kind.title) · \(MarkdownText.escape(period.name)) · From \(start) · Until \(end)"
    }.joined(separator: "\n")
    let facts =
      record.kind == "entity"
      ? try structuredFactMarkdown(worldID: worldID, subjectID: record.id) : ""
    return metadata + heading + illustration + MarkdownText.body(record) + "\n"
      + (properties.isEmpty ? "" : "\n## Structured properties\n\n" + properties + "\n")
      + (nameHistory.isEmpty ? "" : "\n## Names through time\n\n" + nameHistory + "\n")
      + (facts.isEmpty ? "" : "\n## Structured facts\n\n" + facts + "\n")
      + (rules.isEmpty ? "" : "\n## Rules\n\n\(rules)\n")
  }

  private func structuredFactMarkdown(worldID: String, subjectID: String) throws -> String {
    var entries: [String] = []
    for fact in try structuredFacts(worldID: worldID, subjectID: subjectID) {
      var revisions = [fact.working]
      if let accepted = fact.accepted, accepted.id != fact.working.id { revisions.append(accepted) }
      for revision in revisions {
        let value: String
        switch revision.value {
        case .text(let text): value = MarkdownText.escape(text)
        case .entity(let id):
          let entity = try record(worldID: worldID, id: id)
          value = "\(MarkdownText.escape(entity.title)) (\(id))"
        }
        var line =
          "- **\(MarkdownText.escape(fact.predicate))** · \(revision.status.title) · \(value)"
        line += " · \(MarkdownText.escape(revision.author)) · \(revision.recordedAt)"
        if let evidence = revision.evidence {
          let source = try structuredFactSource(worldID: worldID, evidence: evidence)
          line +=
            " · Evidence: \(MarkdownText.escape(source.title)) (\(source.id), revision \(source.version))"
        }
        entries.append(line)
      }
    }
    return entries.joined(separator: "\n")
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
    let related = try relations(worldID: worldID).map { edge in
      let details = edge.attributes
      var values = ["Canon state · \(edge.state)"]
      if details.kind != .unknown { values.append("Kind · \(details.kind.title)") }
      if !details.startLabel.isEmpty { values.append("Start · \(details.startLabel)") }
      if !details.endLabel.isEmpty { values.append("End · \(details.endLabel)") }
      if details.strength != .unknown { values.append("Strength · \(details.strength.title)") }
      if details.secrecy != .unknown { values.append("Secrecy · \(details.secrecy.title)") }
      if details.mutuality != .unknown { values.append("Mutuality · \(details.mutuality.title)") }
      if details.status != .unknown { values.append("Status · \(details.status.title)") }
      let evidence = details.evidenceRecordIDs.map { titles[$0] ?? "Archived source \($0)" }
      if !evidence.isEmpty { values.append("Evidence · \(evidence.joined(separator: ", "))") }
      return
        "- \(titles[edge.sourceID] ?? edge.sourceID) — \(edge.label) → \(titles[edge.targetID] ?? edge.targetID)"
        + values.map { "\n  - \($0)" }.joined()
    }
    files.append(
      (
        "Relationships.md",
        "# Relationships\n\nRelationships between entities in \(world.name).\n\n"
          + (related.isEmpty ? "None yet.\n" : related.joined(separator: "\n") + "\n")
      ))
    let timelineDates = try timelineEventDates(worldID: worldID)
    let calendarName = try timelineCalendar(worldID: worldID)?.name
    let history = try events(worldID: worldID).map { event in
      let originalLabel = event.dateLabel == "unknown" ? "Date unknown" : event.dateLabel
      let source = titles[event.sourceID] ?? "archived record"
      var line = "- **\(originalLabel)** — \(event.title) (source: \(source))"
      if let date = timelineDates[event.id] {
        switch date {
        case .calendarDay:
          line += "\n  - \(date.label) (\(calendarName ?? "Calendar"))"
        case .unknown:
          if event.dateLabel != "unknown" { line += "\n  - Calendar date unknown" }
        }
      }
      return line
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
