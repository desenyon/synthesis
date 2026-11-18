import Foundation

/// Library controls intersect the query before the result limit, never after it.
public struct LoreSearchScope: Sendable {
  public var kind: String?
  public var category: String?
  public var entityTypeID: String?
  public var hasCanon: Bool
  public var sectionsOnly: Bool
  public init(
    kind: String? = nil, category: String? = nil, entityTypeID: String? = nil,
    hasCanon: Bool = false, sectionsOnly: Bool = false
  ) {
    self.kind = kind
    self.category = category
    self.entityTypeID = entityTypeID
    self.hasCanon = hasCanon
    self.sectionsOnly = sectionsOnly
  }
}

extension WorkspaceStore {
  /// Search current-world records. Archive is an explicit Library scope, never mixed into results.
  public func search(
    worldID: String, query: String, archived: Bool = false, now: Date = Date(),
    scope: LoreSearchScope = .init()
  ) throws -> [LoreRecord] {
    _ = try world(worldID)
    let parsed = try LoreSearchQuery.parse(query)
    let phrases = parsed.terms.compactMap { term -> String? in
      let words = term.components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
      return words.isEmpty ? nil : "\"\(words.joined(separator: " "))\"*"
    }
    guard !phrases.isEmpty || parsed.hasFilters else { return [] }
    var values: [String?] = []
    var prefix = ""
    var join = ""
    var order = "r.updated_at DESC,r.rowid DESC"
    var conditions = ["r.world_id=?", "r.archived=?"]
    if !phrases.isEmpty {
      // Without materialization SQLite reruns the virtual FTS scan for each candidate record.
      // Evaluate it once, then join its indexed IDs while preserving substring-title fallback.
      prefix = """
        WITH matches AS MATERIALIZED (
          SELECT id,MIN(rank) AS rank FROM (
            SELECT id,rank FROM records_fts WHERE records_fts MATCH ? AND world_id=?
            UNION ALL SELECT record_id AS id,rank FROM entity_profile_search
              WHERE entity_profile_search MATCH ? AND world_id=?
            UNION ALL SELECT record_id AS id,rank FROM entity_name_search
              WHERE entity_name_search MATCH ? AND world_id=?
          ) GROUP BY id
        )
        """ + " "
      let match = phrases.joined(separator: " AND ")
      values += [match, worldID, match, worldID, match, worldID]
      join = " LEFT JOIN matches ON matches.id=r.id"
      order = "COALESCE(matches.rank,0)," + order
    }
    values += [worldID, archived ? "1" : "0"]
    if let kind = scope.kind {
      conditions.append("r.kind=?")
      values.append(kind)
    }
    if let category = scope.category {
      let names = LoreSearchQuery.categoryNames(category)
      conditions.append(
        "r.category COLLATE synthesis_search IN (\(names.map { _ in "?" }.joined(separator: ",")))")
      values += names
    }
    if let typeID = scope.entityTypeID {
      conditions.append(
        """
        EXISTS (SELECT 1 FROM entity_profiles p JOIN entity_types t
          ON t.id=p.type_id AND t.world_id=p.world_id
          WHERE p.world_id=r.world_id AND p.record_id=r.id AND t.id=? AND t.archived=0)
        """)
      values.append(typeID)
    }
    if scope.hasCanon { conditions.append("(r.state='canon' OR r.canonical IS NOT NULL)") }
    if scope.sectionsOnly {
      conditions.append(
        """
        EXISTS (SELECT 1 FROM record_sections s JOIN records parent
        ON parent.id=s.parent_id AND parent.world_id=s.world_id
        WHERE s.world_id=r.world_id AND s.record_id=r.id AND s.archived=0 AND parent.archived=0)
        """)
    }
    if !phrases.isEmpty {
      let literal = parsed.terms.joined(separator: " ")
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "%", with: "\\%")
        .replacingOccurrences(of: "_", with: "\\_")
      conditions.append(
        "(matches.id IS NOT NULL OR r.title LIKE ? ESCAPE '\\' OR r.category LIKE ? ESCAPE '\\')")
      values += ["%\(literal)%", "%\(literal)%"]
    }
    for filter in parsed.filters {
      let value = filter.value
      switch filter.field {
      case .type, .category:
        let kind: String? =
          filter.field == .type
          ? [
            "document": "lore", "documents": "lore", "lore": "lore", "entity": "entity",
            "entities": "entity", "idea": "capture", "ideas": "capture", "capture": "capture",
          ][value.lowercased()]
          : nil
        if let kind {
          conditions.append("r.kind=?")
          values.append(kind)
        } else {
          let categories = LoreSearchQuery.categoryNames(value)
          conditions.append(
            "r.category COLLATE synthesis_search IN (\(categories.map { _ in "?" }.joined(separator: ",")))"
          )
          values += categories
        }
      case .status:
        conditions.append("r.state=?")
        values.append(value.lowercased())
      case .tag:
        conditions.append(
          "EXISTS (SELECT 1 FROM json_each(r.tags) WHERE value = ? COLLATE synthesis_search)")
        values.append(value)
      case .alias:
        conditions.append(
          """
          (EXISTS (SELECT 1 FROM json_each(r.aliases) WHERE value = ? COLLATE synthesis_search)
          OR EXISTS (SELECT 1 FROM entity_name_periods n
            WHERE n.world_id=r.world_id AND n.record_id=r.id AND n.archived=0 AND n.kind='alias'
              AND n.name = ? COLLATE synthesis_search))
          """)
        values += [value, value]
      case .updated, .created:
        let column = filter.field == .updated ? "updated_at" : "created_at"
        conditions.append("r.\(column)>=? AND r.\(column)<=?")
        values += [
          try LoreSearchQuery.cutoff(value, now: now), ISO8601DateFormatter().string(from: now),
        ]
      case .faction, .related:
        var relation = """
          EXISTS (SELECT 1 FROM relationships link JOIN records other
          ON other.id=CASE WHEN link.source_id=r.id THEN link.target_id ELSE link.source_id END
          WHERE link.world_id=r.world_id AND (link.source_id=r.id OR link.target_id=r.id)
          AND link.archived=0 AND other.world_id=r.world_id AND other.archived=0
          AND (other.title=? COLLATE synthesis_search OR other.id=?
          OR EXISTS (SELECT 1 FROM json_each(other.aliases) WHERE value=? COLLATE synthesis_search))
          """
        values += [value, value, value]
        if filter.field == .faction {
          let categories = LoreSearchQuery.categoryNames("systems")
          relation +=
            " AND other.category COLLATE synthesis_search IN (\(categories.map { _ in "?" }.joined(separator: ",")))"
          values += categories
        }
        conditions.append(relation + ")")
      }
    }
    let sql =
      prefix + "SELECT r.*,d.rtf FROM records r LEFT JOIN rich_documents d ON d.record_id=r.id"
      + join + " WHERE " + conditions.joined(separator: " AND ") + " ORDER BY \(order) LIMIT 50"
    return try db.rows(sql, values).map(decodeRecord)
  }
}
