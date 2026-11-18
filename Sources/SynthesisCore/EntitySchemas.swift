import Foundation

extension WorkspaceStore {
  public func entityTypes(worldID: String, includingArchived: Bool = false) throws -> [EntityType] {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM entity_types WHERE world_id=? \(includingArchived ? "" : "AND archived=0") ORDER BY name COLLATE NOCASE,id",
      [worldID]
    ).map(entityTypeRow)
  }
  public func entityType(worldID: String, id: String) throws -> EntityType {
    guard
      let row = try db.rows("SELECT * FROM entity_types WHERE world_id=? AND id=?", [worldID, id])
        .first
    else { throw SynthesisError.notFound }
    return try entityTypeRow(row)
  }
  public func resolvedEntityType(worldID: String, id: String) throws -> EntityResolvedType {
    var chain: [EntityType] = []
    var seen: Set<String> = []
    var next: String? = id
    while let current = next {
      guard seen.insert(current).inserted, chain.count < 16 else {
        throw SynthesisError.invalid(
          "Entity types cannot inherit in a cycle or exceed 16 generations.")
      }
      let type = try entityType(worldID: worldID, id: current)
      chain.append(type)
      next = type.parentTypeID
    }
    var fields: [EntityField] = []
    var defaults: [String: EntityValue] = [:]
    var sources: [String: String] = [:]
    for type in chain.reversed() {
      for field in type.fields {
        if let index = fields.firstIndex(where: { $0.key == field.key }) {
          fields[index] = field
        } else {
          fields.append(field)
        }
        sources[field.key] = type.id
      }
      defaults.merge(type.defaults) { _, new in new }
    }
    guard let type = chain.first else { throw SynthesisError.notFound }
    return EntityResolvedType(
      type: type, ancestors: Array(chain.dropFirst().reversed()), fields: fields,
      defaults: defaults, sources: sources)
  }
  @discardableResult public func saveEntityType(
    worldID: String, id: String? = nil, expectedVersion: Int? = nil,
    name: String, description: String = "", parentTypeID: String? = nil,
    fields: [EntityField], defaults: [String: EntityValue] = [:]
  ) throws -> EntityType {
    try db.transaction {
      _ = try world(worldID)
      let clean = try entityLabel(name, limit: 120, noun: "type name")
      guard description.count <= 4000, fields.count <= 100,
        Set(fields.map(\.key)).count == fields.count
      else {
        throw SynthesisError.invalid(
          "Use at most 100 uniquely keyed fields and a description up to 4000 characters.")
      }
      if let parentTypeID { _ = try entityType(worldID: worldID, id: parentTypeID) }
      let existing = try id.map { try entityType(worldID: worldID, id: $0) }
      guard existing?.version == expectedVersion else { throw SynthesisError.stale }
      let id = existing?.id ?? UUID().uuidString
      let now = timestamp()
      guard
        try db.rows(
          "SELECT id FROM entity_types WHERE world_id=? AND name=? COLLATE synthesis_search AND id!=? AND archived=0",
          [worldID, clean, id]
        ).isEmpty
      else {
        throw SynthesisError.invalid("An active type already uses that name.")
      }
      if let existing {
        try db.execute(
          "UPDATE entity_types SET name=?,description=?,parent_type_id=?,fields_json=?,defaults_json=?,version=version+1,updated_at=? WHERE id=? AND world_id=?",
          [
            clean, description, parentTypeID, try schemaJSON(fields), try schemaJSON(defaults), now,
            existing.id, worldID,
          ])
      } else {
        try db.execute(
          "INSERT INTO entity_types(id,world_id,name,description,parent_type_id,fields_json,defaults_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
          [
            id, worldID, clean, description, parentTypeID, try schemaJSON(fields),
            try schemaJSON(defaults), now, now,
          ])
      }
      // Validate descendants, profiles and templates atomically. Incompatible edits roll back.
      try validateEntitySchemas(worldID: worldID, history: false)
      try refreshEntityPropertySearch(worldID: worldID)
      let result = try entityType(worldID: worldID, id: id)
      try db.execute(
        "INSERT INTO entity_type_history VALUES(?,?,?,?,?,?)",
        [UUID().uuidString, worldID, id, String(result.version), try schemaJSON(result), now])
      return result
    }
  }
  public func setEntityTypeArchived(
    worldID: String, id: String, archived: Bool, expectedVersion: Int
  ) throws {
    try db.transaction {
      let type = try entityType(worldID: worldID, id: id)
      guard type.version == expectedVersion else { throw SynthesisError.stale }
      if !archived {
        guard
          try db.rows(
            "SELECT id FROM entity_types WHERE world_id=? AND name=? COLLATE synthesis_search AND archived=0 AND id!=?",
            [worldID, type.name, id]
          ).isEmpty
        else {
          throw SynthesisError.invalid(
            "Another active type has this name. Rename this type before restoring it.")
        }
      }
      try db.execute(
        "UPDATE entity_types SET archived=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [archived ? "1" : "0", timestamp(), worldID, id])
      let result = try entityType(worldID: worldID, id: id)
      try db.execute(
        "INSERT INTO entity_type_history VALUES(?,?,?,?,?,?)",
        [
          UUID().uuidString, worldID, id, String(result.version), try schemaJSON(result),
          timestamp(),
        ])
    }
  }
  public func entityProfile(worldID: String, recordID: String) throws -> EntityProfile? {
    _ = try record(worldID: worldID, id: recordID)
    return try db.rows(
      "SELECT * FROM entity_profiles WHERE world_id=? AND record_id=?", [worldID, recordID]
    ).first.map(entityProfileRow)
  }
  @discardableResult public func saveEntityProfile(
    worldID: String, recordID: String, typeID: String,
    values: [String: EntityValue], expectedVersion: Int?
  ) throws -> EntityProfile {
    try db.transaction {
      let record = try record(worldID: worldID, id: recordID)
      guard record.kind == "entity", try !isArchived(worldID: worldID, recordID: recordID) else {
        throw SynthesisError.invalid("Properties belong to an active entity.")
      }
      let current = try entityProfile(worldID: worldID, recordID: recordID)
      guard current?.version == expectedVersion else { throw SynthesisError.stale }
      let resolved = try resolvedEntityType(worldID: worldID, id: typeID)
      guard !resolved.type.archived || current?.typeID == typeID else {
        throw SynthesisError.invalid("Restore this type before assigning it to another entity.")
      }
      try validateEntityValues(worldID: worldID, values: values, fields: resolved.fields)
      let now = timestamp()
      if let current {
        try db.execute(
          "UPDATE entity_profiles SET type_id=?,values_json=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
          [typeID, try schemaJSON(values), now, worldID, current.id])
      } else {
        try db.execute(
          "INSERT INTO entity_profiles(id,world_id,record_id,type_id,values_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?)",
          [UUID().uuidString, worldID, recordID, typeID, try schemaJSON(values), now, now])
      }
      let profile = try entityProfile(worldID: worldID, recordID: recordID)!
      try snapshotEntityProfile(profile)
      try refreshEntityPropertySearch(worldID: worldID, recordID: recordID)
      return profile
    }
  }
  public func entityProfileReview(worldID: String, recordID: String) throws -> EntityProfileReview?
  {
    guard let profile = try entityProfile(worldID: worldID, recordID: recordID) else { return nil }
    let resolved = try resolvedEntityType(worldID: worldID, id: profile.typeID)
    var values = resolved.defaults.merging(profile.values) { _, new in new }
    let computation = EntityFormulaValues(fields: resolved.fields, values: values)
    var issues: [String: String] = [:]
    for field in resolved.fields where field.kind == .formula {
      do { values[field.key] = .number(try computation.resolve(field.key)) } catch {
        values[field.key] = .unknown
        issues[field.key] = error.localizedDescription
      }
    }
    let visible = resolved.fields.filter { field in
      guard let condition = field.condition else { return true }
      let actual = values[condition.field] ?? .unknown
      switch (actual, condition.equals) {
      case (.selections(let left), .selections(let right)),
        (.entities(let left), .entities(let right)):
        return Set(left) == Set(right)
      default: return actual == condition.equals
      }
    }.map(\.key)
    let snapshot = EntityPropertySnapshot(
      typeID: profile.typeID, typeName: resolved.type.name, fields: resolved.fields, values: values,
      visibleKeys: visible)
    let versions = (resolved.ancestors + [resolved.type]).map { "\($0.id):\($0.version)" }.joined(
      separator: ",")
    return EntityProfileReview(
      profile: profile, snapshot: snapshot, issues: issues,
      revision: "\(profile.id):\(profile.version):\(versions)"
    )
  }
  /// Only the creator-facing review UI may call this method; it is deliberately absent from agent tools.
  @discardableResult public func acceptEntityProperties(
    worldID: String, recordID: String, confirmedProfileID: String,
    expectedRevision: String
  ) throws -> EntityProfile {
    try db.transaction {
      guard let review = try entityProfileReview(worldID: worldID, recordID: recordID),
        review.profile.id == confirmedProfileID, review.revision == expectedRevision
      else { throw SynthesisError.stale }
      guard try !isArchived(worldID: worldID, recordID: recordID) else {
        throw SynthesisError.invalid("Restore the entity before accepting its properties.")
      }
      try validateEntitySnapshot(worldID: worldID, snapshot: review.snapshot)
      try db.execute(
        "UPDATE entity_profiles SET canonical_json=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [try schemaJSON(review.snapshot), timestamp(), worldID, confirmedProfileID])
      let profile = try entityProfile(worldID: worldID, recordID: recordID)!
      try snapshotEntityProfile(profile)
      try refreshEntityPropertySearch(worldID: worldID, recordID: recordID)
      return profile
    }
  }
  public func entityProfileHistory(worldID: String, recordID: String) throws
    -> [EntityProfileRevision]
  {
    guard let profile = try entityProfile(worldID: worldID, recordID: recordID) else { return [] }
    return try db.rows(
      "SELECT * FROM entity_profile_history WHERE world_id=? AND profile_id=? ORDER BY version DESC",
      [worldID, profile.id]
    ).map {
      EntityProfileRevision(
        id: $0["id"]!, profile: try schemaDecode(EntityProfile.self, $0["snapshot_json"]!),
        createdAt: $0["created_at"]!)
    }
  }
  public func restoreEntityProfile(
    worldID: String, recordID: String, revisionID: String, expectedVersion: Int
  ) throws -> EntityProfile {
    guard
      let revision = try entityProfileHistory(worldID: worldID, recordID: recordID).first(where: {
        $0.id == revisionID
      })
    else { throw SynthesisError.notFound }
    return try saveEntityProfile(
      worldID: worldID, recordID: recordID, typeID: revision.profile.typeID,
      values: revision.profile.values, expectedVersion: expectedVersion)
  }
  public func entityTemplates(worldID: String, includingArchived: Bool = false) throws
    -> [EntityTemplate]
  {
    _ = try world(worldID)
    return try db.rows(
      "SELECT * FROM entity_templates WHERE world_id=? \(includingArchived ? "" : "AND archived=0") ORDER BY name COLLATE NOCASE,id",
      [worldID]
    ).map(entityTemplateRow)
  }
  @discardableResult public func saveEntityTemplate(
    worldID: String, id: String? = nil, expectedVersion: Int? = nil,
    typeID: String, name: String, description: String = "", body: String = "",
    values: [String: EntityValue] = [:]
  ) throws -> EntityTemplate {
    try db.transaction {
      let clean = try entityLabel(name, limit: 120, noun: "template name")
      guard description.count <= 4000, body.count <= 200_000 else {
        throw SynthesisError.invalid("Template text is too long.")
      }
      let type = try resolvedEntityType(worldID: worldID, id: typeID)
      guard !type.type.archived else {
        throw SynthesisError.invalid("Restore this type before making a template.")
      }
      try validateEntityValues(worldID: worldID, values: values, fields: type.fields)
      let existing = try id.map { id in
        guard
          let item = try entityTemplates(worldID: worldID, includingArchived: true).first(where: {
            $0.id == id
          })
        else { throw SynthesisError.notFound }
        return item
      }
      guard existing?.version == expectedVersion else { throw SynthesisError.stale }
      let id = existing?.id ?? UUID().uuidString
      let now = timestamp()
      if existing != nil {
        try db.execute(
          "UPDATE entity_templates SET type_id=?,name=?,description=?,body=?,values_json=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
          [typeID, clean, description, body, try schemaJSON(values), now, worldID, id])
      } else {
        try db.execute(
          "INSERT INTO entity_templates(id,world_id,type_id,name,description,body,values_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
          [id, worldID, typeID, clean, description, body, try schemaJSON(values), now, now])
      }
      let template = try entityTemplates(worldID: worldID, includingArchived: true).first {
        $0.id == id
      }!
      try snapshotEntityTemplate(template)
      return template
    }
  }
  public func setEntityTemplateArchived(
    worldID: String, id: String, archived: Bool, expectedVersion: Int
  ) throws {
    try db.transaction {
      guard
        let item = try entityTemplates(worldID: worldID, includingArchived: true).first(where: {
          $0.id == id
        })
      else { throw SynthesisError.notFound }
      guard item.version == expectedVersion else { throw SynthesisError.stale }
      try db.execute(
        "UPDATE entity_templates SET archived=?,version=version+1,updated_at=? WHERE world_id=? AND id=?",
        [archived ? "1" : "0", timestamp(), worldID, id])
      let saved = try entityTemplates(worldID: worldID, includingArchived: true).first {
        $0.id == id
      }!
      try snapshotEntityTemplate(saved)
    }
  }
  @discardableResult public func createTypedEntity(
    worldID: String, typeID: String, title: String, templateID: String? = nil
  ) throws -> LoreRecord {
    try db.transaction {
      let type = try entityType(worldID: worldID, id: typeID)
      guard !type.archived else {
        throw SynthesisError.invalid("Restore this type before creating an entity.")
      }
      var template: EntityTemplate?
      if let templateID {
        guard
          let item = try entityTemplates(worldID: worldID).first(where: { $0.id == templateID }),
          item.typeID == typeID
        else { throw SynthesisError.notFound }
        template = item
      }
      let record = try createRecord(
        worldID: worldID,
        title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ? "Untitled \(type.name)" : title, body: template?.body ?? "", kind: "entity",
        category: type.name)
      _ = try saveEntityProfile(
        worldID: worldID, recordID: record.id, typeID: typeID, values: template?.values ?? [:],
        expectedVersion: nil)
      return record
    }
  }

  public func entityTypeHistory(worldID: String, typeID: String) throws -> [EntityType] {
    _ = try entityType(worldID: worldID, id: typeID)
    return try db.rows(
      "SELECT snapshot_json FROM entity_type_history WHERE world_id=? AND type_id=? ORDER BY version DESC",
      [worldID, typeID]
    ).map { try schemaDecode(EntityType.self, $0["snapshot_json"]!) }
  }
  public func entityTemplateHistory(worldID: String, templateID: String) throws -> [EntityTemplate]
  {
    guard
      try entityTemplates(worldID: worldID, includingArchived: true).contains(where: {
        $0.id == templateID
      })
    else { throw SynthesisError.notFound }
    return try db.rows(
      "SELECT snapshot_json FROM entity_template_history WHERE world_id=? AND template_id=? ORDER BY version DESC",
      [worldID, templateID]
    ).map { try schemaDecode(EntityTemplate.self, $0["snapshot_json"]!) }
  }
  private func snapshotEntityTemplate(_ template: EntityTemplate) throws {
    try db.execute(
      "INSERT INTO entity_template_history VALUES(?,?,?,?,?,?)",
      [
        UUID().uuidString, template.worldID, template.id, String(template.version),
        try schemaJSON(template), timestamp(),
      ])
  }
  // MARK: Validation shared by writes and portable imports
  func validateEntitySchemas(worldID: String, history: Bool = true) throws {
    let types = try entityTypes(worldID: worldID, includingArchived: true)
    guard types.count <= 1000 else {
      throw SynthesisError.invalid("A world supports up to 1000 entity types.")
    }
    for type in types {
      _ = try entityLabel(type.name, limit: 120, noun: "type name")
      guard type.version > 0, type.description.count <= 4000, type.fields.count <= 100,
        Set(type.fields.map(\.key)).count == type.fields.count
      else { throw SynthesisError.invalid("Invalid entity schema.") }
      let resolved = try resolvedEntityType(worldID: worldID, id: type.id)
      try validateEntityFields(resolved.fields)
      try validateEntityConditions(worldID: worldID, fields: resolved.fields)
      try validateEntityValues(worldID: worldID, values: resolved.defaults, fields: resolved.fields)
    }
    for row in try db.rows("SELECT * FROM entity_profiles WHERE world_id=?", [worldID]) {
      let profile = try entityProfileRow(row)
      guard try record(worldID: worldID, id: profile.recordID).kind == "entity", profile.version > 0
      else { throw SynthesisError.invalid("Properties must belong to an entity in this world.") }
      let resolved = try resolvedEntityType(worldID: worldID, id: profile.typeID)
      try validateEntityValues(worldID: worldID, values: profile.values, fields: resolved.fields)
      if let canonical = profile.canonical {
        try validateEntitySnapshot(worldID: worldID, snapshot: canonical)
      }
    }
    for item in try entityTemplates(worldID: worldID, includingArchived: true) {
      _ = try entityLabel(item.name, limit: 120, noun: "template name")
      guard item.version > 0, item.body.count <= 200_000, item.description.count <= 4000 else {
        throw SynthesisError.invalid("Invalid entity template.")
      }
      try validateEntityValues(
        worldID: worldID, values: item.values,
        fields: resolvedEntityType(worldID: worldID, id: item.typeID).fields)
    }
    if history {
      for row in try db.rows("SELECT * FROM entity_template_history WHERE world_id=?", [worldID]) {
        let template = try schemaDecode(EntityTemplate.self, row["snapshot_json"]!)
        guard template.worldID == worldID, template.id == row["template_id"],
          String(template.version) == row["version"],
          try entityTemplates(worldID: worldID, includingArchived: true).contains(where: {
            $0.id == template.id
          })
        else { throw SynthesisError.invalid("Invalid template history.") }
        _ = try entityLabel(template.name, limit: 120, noun: "template name")
        guard template.version > 0, template.description.count <= 4000,
          template.body.count <= 200_000
        else { throw SynthesisError.invalid("Invalid template history payload.") }
        _ = try entityType(worldID: worldID, id: template.typeID)
        try validateHistoricEntityValues(worldID: worldID, values: template.values)
      }
      for row in try db.rows(
        "SELECT h.*,p.record_id FROM entity_profile_history h JOIN entity_profiles p ON p.id=h.profile_id AND p.world_id=h.world_id WHERE h.world_id=?",
        [worldID])
      {
        let profile = try schemaDecode(EntityProfile.self, row["snapshot_json"]!)
        guard profile.worldID == worldID, profile.id == row["profile_id"],
          profile.recordID == row["record_id"], String(profile.version) == row["version"]
        else { throw SynthesisError.invalid("Invalid property history.") }
        _ = try entityType(worldID: worldID, id: profile.typeID)
        // Historic values may use retired keys; references and media still must be local and safe.
        try validateHistoricEntityValues(worldID: worldID, values: profile.values)
        if let canonical = profile.canonical {
          try validateEntitySnapshot(worldID: worldID, snapshot: canonical)
        }
      }
      for row in try db.rows("SELECT * FROM entity_type_history WHERE world_id=?", [worldID]) {
        let type = try schemaDecode(EntityType.self, row["snapshot_json"]!)
        guard type.worldID == worldID, type.id == row["type_id"],
          String(type.version) == row["version"]
        else { throw SynthesisError.invalid("Invalid entity type history.") }
        _ = try entityLabel(type.name, limit: 120, noun: "type name")
        guard type.version > 0, type.description.count <= 4000 else {
          throw SynthesisError.invalid("Invalid type history payload.")
        }
        try validateEntityFields(type.fields, resolved: false)
        if let parent = type.parentTypeID { _ = try entityType(worldID: worldID, id: parent) }
        try validateHistoricEntityValues(worldID: worldID, values: type.defaults)
        try validateEntityConditions(worldID: worldID, fields: type.fields)
      }
    }
  }
  private func validateEntitySnapshot(worldID: String, snapshot: EntityPropertySnapshot) throws {
    _ = try entityType(worldID: worldID, id: snapshot.typeID)
    _ = try entityLabel(snapshot.typeName, limit: 120, noun: "accepted type name")
    try validateEntityFields(snapshot.fields)
    try validateEntityConditions(worldID: worldID, fields: snapshot.fields)
    guard Set(snapshot.visibleKeys).isSubset(of: Set(snapshot.fields.map(\.key))) else {
      throw SynthesisError.invalid("Invalid property visibility.")
    }
    try validateEntityValues(
      worldID: worldID, values: snapshot.values, fields: snapshot.fields, computed: true)
  }
  private func validateEntityFields(_ fields: [EntityField], resolved: Bool = true) throws {
    guard fields.count <= 100, Set(fields.map(\.key)).count == fields.count else {
      throw SynthesisError.invalid("Use at most 100 unique fields.")
    }
    let byKey = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0) })
    var checked = Set<String>()
    for field in fields {
      guard field.key.range(of: "^[a-z][a-z0-9_]{0,47}$", options: .regularExpression) != nil,
        !field.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        field.label.count <= 120,
        field.note.count <= 2000, field.formula.count <= 1000, field.options.count <= 100,
        field.options.allSatisfy({ $0.count <= 120 })
      else {
        throw SynthesisError.invalid(
          "Fields need a label and a unique lowercase key (letters, numbers, underscores).")
      }
      if [.selection, .selections].contains(field.kind) {
        guard !field.options.isEmpty, field.options.count <= 100,
          Set(field.options).count == field.options.count,
          field.options.allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 120
          })
        else { throw SynthesisError.invalid("Selections need 1–100 unique, nonempty choices.") }
      }
      if let condition = field.condition {
        guard condition.field != field.key,
          condition.field.range(of: "^[a-z][a-z0-9_]{0,47}$", options: .regularExpression) != nil,
          !resolved || byKey[condition.field] != nil
        else {
          throw SynthesisError.invalid(
            "Conditional fields must reference a different existing field.")
        }
        if let target = byKey[condition.field] {
          try validateEntityValue(condition.equals, field: target, computed: true)
        }
      }
      if field.kind == .formula {
        let references = try EntityFormula.references(field.formula)
        for key in references {
          guard !resolved || byKey[key].map({ [.number, .formula].contains($0.kind) }) == true
          else {
            throw SynthesisError.invalid(
              "Formula \(field.label) must reference numeric or computed fields in this type.")
          }
        }
        try validateFormulaCycles(field.key, fields: byKey, visiting: [], checked: &checked)
        try EntityFormula.validateSyntax(field.formula)
      }
    }
  }
  private func validateEntityConditions(worldID: String, fields: [EntityField]) throws {
    for field in fields {
      if let condition = field.condition {
        try validateHistoricEntityValues(
          worldID: worldID, values: [condition.field: condition.equals])
      }
    }
  }
  private func validateFormulaCycles(
    _ key: String, fields: [String: EntityField], visiting: Set<String>, checked: inout Set<String>
  ) throws {
    if checked.contains(key) { return }
    guard !visiting.contains(key), visiting.count < 100 else {
      throw SynthesisError.invalid(
        "Computed fields cannot depend on themselves, including indirectly.")
    }
    guard let field = fields[key], field.kind == .formula else { return }
    for dependency in try EntityFormula.references(field.formula) {
      try validateFormulaCycles(
        dependency, fields: fields, visiting: visiting.union([key]), checked: &checked)
    }
    checked.insert(key)
  }
  private func validateEntityValues(
    worldID: String, values: [String: EntityValue], fields: [EntityField], computed: Bool = false
  ) throws {
    guard values.count <= 100 else { throw SynthesisError.invalid("Too many property values.") }
    for (key, value) in values {
      guard let field = fields.first(where: { $0.key == key }) else {
        throw SynthesisError.invalid(
          "The field \(key) has saved values. Keep it in the type or remove its overrides before changing the schema."
        )
      }
      try validateEntityValue(value, field: field, computed: computed)
    }
    try validateHistoricEntityValues(worldID: worldID, values: values)
  }
  private func validateHistoricEntityValues(worldID: String, values: [String: EntityValue]) throws {
    guard values.count <= 100, try schemaJSON(values).utf8.count <= 24_000_000 else {
      throw SynthesisError.invalid(
        "A structured profile can contain up to 100 values and 24 MB of embedded data.")
    }
    for value in values.values {
      let bounded: Bool
      switch value {
      case .text(let text), .date(let text): bounded = text.count <= 20_000
      case .number(let number): bounded = number.isFinite
      case .range(let low, let high): bounded = low.isFinite && high.isFinite && low <= high
      case .duration(let amount, let unit):
        bounded = amount.isFinite && amount >= 0 && !unit.isEmpty && unit.count <= 120
      case .selection(let choice): bounded = !choice.isEmpty && choice.count <= 120
      case .selections(let choices):
        bounded =
          choices.count <= 100 && Set(choices).count == choices.count
          && choices.allSatisfy { !$0.isEmpty && $0.count <= 120 }
      case .coordinates(let x, let y, let unit):
        bounded = x.isFinite && y.isFinite && unit.count <= 120
      default: bounded = true
      }
      guard bounded else {
        throw SynthesisError.invalid("A property history value is outside the supported bounds.")
      }
      let references: [String]
      switch value {
      case .entity(let id): references = [id]
      case .entities(let ids): references = ids
      default: references = []
      }
      guard references.count <= 100, Set(references).count == references.count else {
        throw SynthesisError.invalid("Choose up to 100 different linked entities.")
      }
      for id in references {
        guard try record(worldID: worldID, id: id).kind == "entity" else {
          throw SynthesisError.invalid(
            "A linked property must refer to an entity in this universe.")
        }
      }
      if case .media(let name, let mime, let base64) = value {
        guard !name.isEmpty, name.count <= 255, base64.utf8.count <= 8_000_000,
          let data = Data(base64Encoded: base64), try Self.validateArtwork(data) == mime
        else {
          throw SynthesisError.invalid(
            "Property images must be valid PNG or JPEG files up to 6 MB.")
        }
      }
      guard (try schemaJSON(value)).utf8.count <= 8_001_000 else {
        throw SynthesisError.invalid("This property is too large.")
      }
    }
  }
  private func validateEntityValue(_ value: EntityValue, field: EntityField, computed: Bool) throws
  {
    guard field.kind != .formula || computed else {
      throw SynthesisError.invalid("Computed fields cannot store manual overrides.")
    }
    if value == .unknown { return }
    let valid: Bool
    switch (field.kind, value) {
    case (.text, .text(let text)), (.date, .date(let text)): valid = text.count <= 20_000
    case (.boolean, .boolean): valid = true
    case (.number, .number(let number)): valid = number.isFinite
    case (.formula, .number(let number)): valid = computed && number.isFinite
    case (.range, .range(let low, let high)): valid = low.isFinite && high.isFinite && low <= high
    case (.duration, .duration(let amount, let unit)):
      valid = amount.isFinite && amount >= 0 && !unit.isEmpty && unit.count <= 120
    case (.selection, .selection(let choice)): valid = field.options.contains(choice)
    case (.selections, .selections(let choices)):
      valid =
        choices.count <= 100 && Set(choices).count == choices.count
        && choices.allSatisfy(field.options.contains)
    case (.entity, .entity): valid = true
    case (.entities, .entities(let ids)): valid = ids.count <= 100 && Set(ids).count == ids.count
    case (.coordinates, .coordinates(let x, let y, let unit)):
      valid = x.isFinite && y.isFinite && unit.count <= 120
    case (.media, .media): valid = true
    default: valid = false
    }
    guard valid else {
      throw SynthesisError.invalid(
        "\(field.label) needs a valid \(field.kind.label.lowercased()) value.")
    }
  }
  private func snapshotEntityProfile(_ profile: EntityProfile) throws {
    try db.execute(
      "INSERT INTO entity_profile_history VALUES(?,?,?,?,?,?)",
      [
        UUID().uuidString, profile.worldID, profile.id, String(profile.version),
        try schemaJSON(profile), timestamp(),
      ])
  }
  private func entityTypeRow(_ row: [String: String]) throws -> EntityType {
    EntityType(
      id: row["id"]!, worldID: row["world_id"]!, name: row["name"]!,
      description: row["description"]!, parentTypeID: row["parent_type_id"],
      fields: try schemaDecode([EntityField].self, row["fields_json"]!),
      defaults: try schemaDecode([String: EntityValue].self, row["defaults_json"]!),
      version: Int(row["version"]!) ?? 0, archived: row["archived"] == "1",
      createdAt: row["created_at"]!, updatedAt: row["updated_at"]!)
  }
  private func entityProfileRow(_ row: [String: String]) throws -> EntityProfile {
    EntityProfile(
      id: row["id"]!, worldID: row["world_id"]!, recordID: row["record_id"]!,
      typeID: row["type_id"]!,
      values: try schemaDecode([String: EntityValue].self, row["values_json"]!),
      canonical: try row["canonical_json"].map {
        try schemaDecode(EntityPropertySnapshot.self, $0)
      }, version: Int(row["version"]!) ?? 0, createdAt: row["created_at"]!,
      updatedAt: row["updated_at"]!)
  }
  private func entityTemplateRow(_ row: [String: String]) throws -> EntityTemplate {
    EntityTemplate(
      id: row["id"]!, worldID: row["world_id"]!, typeID: row["type_id"]!, name: row["name"]!,
      description: row["description"]!, body: row["body"]!,
      values: try schemaDecode([String: EntityValue].self, row["values_json"]!),
      version: Int(row["version"]!) ?? 0, archived: row["archived"] == "1",
      createdAt: row["created_at"]!, updatedAt: row["updated_at"]!)
  }
  private func entityLabel(_ value: String, limit: Int, noun: String) throws -> String {
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty, clean.count <= limit else {
      throw SynthesisError.invalid("Enter a \(noun) of 1–\(limit) characters.")
    }
    return clean
  }
}
func schemaJSON<T: Encodable>(_ value: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return String(decoding: try encoder.encode(value), as: UTF8.self)
}
func schemaDecode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
  do { return try JSONDecoder().decode(type, from: Data(json.utf8)) } catch {
    throw SynthesisError.invalid(
      "Structured properties could not be read. The original data is preserved.")
  }
}
