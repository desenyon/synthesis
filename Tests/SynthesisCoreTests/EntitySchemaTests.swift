import Foundation
import Testing

@testable import SynthesisCore

struct EntitySchemaTests {
  let life = EntityField(key: "living", label: "Living", kind: .boolean)
  let strength = EntityField(key: "strength", label: "Strength", kind: .number)

  @Test func customTypesInheritSelectivelyPersistAndPreserveExistingWriting() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("schema.sqlite").path
    let store = try WorkspaceStore(path: path)
    let world = try store.createWorld(name: "Aster")
    let parent = try store.saveEntityType(
      worldID: world.id, name: "Species", fields: [life, strength],
      defaults: ["living": .boolean(true), "strength": .number(4)])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Tideborn", parentTypeID: parent.id,
      fields: [EntityField(key: "ancestry", label: "Ancestry")],
      defaults: ["strength": .number(8), "ancestry": .text("Pelagic")])
    var record = try store.createRecord(
      worldID: world.id, title: "Mira", body: "The existing lore stays unchanged.", kind: "entity",
      category: "Characters")
    record = try store.promote(
      worldID: world.id, id: record.id, version: record.version, confirmation: record.id)
    let profile = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id, values: ["strength": .number(10)],
      expectedVersion: nil)
    let reopened = try WorkspaceStore(path: path)
    let review = try #require(
      try reopened.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(review.snapshot.values["strength"] == .number(10))
    #expect(review.snapshot.values["living"] == .boolean(true))
    #expect(review.snapshot.values["ancestry"] == .text("Pelagic"))
    #expect(try reopened.record(worldID: world.id, id: record.id) == record)
    #expect(
      try reopened.resolvedEntityType(worldID: world.id, id: child.id).ancestors.map(\.id) == [
        parent.id
      ])
    _ = try reopened.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id, values: [:],
      expectedVersion: profile.version)
    #expect(
      try reopened.entityProfileReview(worldID: world.id, recordID: record.id)?.snapshot.values[
        "strength"] == .number(8))
    #expect(try reopened.search(worldID: world.id, query: "Pelagic").map(\.id) == [record.id])
    #expect(try reopened.entityTypeHistory(worldID: world.id, typeID: child.id).count == 1)
  }

  @Test func everyTypedValueValidatesAndFormulaCalculatesWithoutExecutableCode() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let place = try store.createRecord(worldID: world.id, title: "The Glass Sea", kind: "entity")
    let fields = [
      EntityField(key: "notes", label: "Notes"), strength, life,
      EntityField(key: "born", label: "Born", kind: .date),
      EntityField(key: "reach", label: "Reach", kind: .range),
      EntityField(key: "training", label: "Training", kind: .duration),
      EntityField(key: "rank", label: "Rank", kind: .selection, options: ["Novice", "Adept"]),
      EntityField(key: "home", label: "Home", kind: .entity),
      EntityField(key: "position", label: "Position", kind: .coordinates),
      EntityField(key: "portrait", label: "Portrait", kind: .media),
      EntityField(
        key: "power", label: "Power", kind: .formula, formula: "strength * 2 + max(3, 1)"),
    ]
    let type = try store.saveEntityType(worldID: world.id, name: "Navigator", fields: fields)
    let record = try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Mira")
    let values: [String: EntityValue] = [
      "notes": .text("Salt charting"), "strength": .number(7), "living": .boolean(true),
      "born": .date("Year -40 · approximate"), "reach": .range(2, 9),
      "training": .duration(12, "seasons"),
      "rank": .selection("Adept"), "home": .entity(place.id),
      "position": .coordinates(-4, 12.5, "harbour grid"),
      "portrait": .media(
        name: "Mira.png", mime: "image/png", base64: RecordArtworkTests.png.base64EncodedString()),
    ]
    let profile = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: type.id, values: values, expectedVersion: 1)
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(review.snapshot.values["power"] == .number(17))
    #expect(profile.values == values)
    for invalid: [String: EntityValue] in [
      ["strength": .text("seven")], ["reach": .range(8, 2)], ["training": .duration(-1, "seasons")],
      ["training": .duration(2, "")], ["rank": .selection("Invented")], ["power": .number(200)],
      ["power": .unknown], ["not_in_schema": .text("lost")],
      ["portrait": .media(name: "x.png", mime: "image/png", base64: "bm90IGFuIGltYWdl")],
    ] {
      #expect(throws: SynthesisError.self) {
        try store.saveEntityProfile(
          worldID: world.id, recordID: record.id, typeID: type.id, values: invalid,
          expectedVersion: profile.version)
      }
    }
    #expect(try store.entityProfile(worldID: world.id, recordID: record.id) == profile)
    #expect(throws: SynthesisError.self) { try EntityFormula.evaluate("system('rm')") { _ in 0 } }
    #expect(throws: SynthesisError.self) { try EntityFormula.evaluate("1 / 0") { _ in 0 } }
    #expect(
      try EntityFormula.evaluate("round(2.5) + floor(2.8) + ceil(0.1) + abs(-3) + 8 % 3") { _ in 0 }
        == 11)
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, name: "Bad formula",
        fields: [EntityField(key: "a", label: "A", kind: .formula, formula: "min(3)")])
    }
  }

  @Test func conditionalVisibilityRetainsValuesAndCanonNeverFollowsDefaultsSilently() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let cause = EntityField(
      key: "cause", label: "Cause of death",
      condition: .init(field: "living", equals: .boolean(false)))
    var type = try store.saveEntityType(
      worldID: world.id, name: "Character", fields: [life, cause, strength],
      defaults: ["living": .boolean(true), "strength": .number(4)])
    let record = try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Mira")
    var profile = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: type.id,
      values: ["cause": .text("The winter crossing")], expectedVersion: 1)
    var review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(!review.snapshot.visibleKeys.contains("cause"))
    #expect(review.snapshot.values["cause"] == .text("The winter crossing"))
    #expect(throws: SynthesisError.self) {
      try store.acceptEntityProperties(
        worldID: world.id, recordID: record.id, confirmedProfileID: "wrong",
        expectedRevision: review.revision)
    }
    profile = try store.acceptEntityProperties(
      worldID: world.id, recordID: record.id, confirmedProfileID: profile.id,
      expectedRevision: review.revision)
    let accepted = profile.canonical
    review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(review.isCanon)
    type = try store.saveEntityType(
      worldID: world.id, id: type.id, expectedVersion: type.version, name: type.name,
      fields: type.fields, defaults: ["living": .boolean(false), "strength": .number(9)])
    #expect(throws: SynthesisError.self) {
      try store.acceptEntityProperties(
        worldID: world.id, recordID: record.id, confirmedProfileID: profile.id,
        expectedRevision: review.revision)
    }
    let changed = try #require(
      try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(!changed.isCanon && changed.snapshot.visibleKeys.contains("cause"))
    #expect(changed.profile.canonical == accepted)
    #expect(changed.snapshot.values["strength"] == .number(9))
    profile = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: type.id,
      values: ["living": .boolean(true), "cause": .text("A hypothetical fate")],
      expectedVersion: profile.version)
    #expect(profile.canonical == accepted)
    let first = try #require(
      try store.entityProfileHistory(worldID: world.id, recordID: record.id).last)
    let restored = try store.restoreEntityProfile(
      worldID: world.id, recordID: record.id, revisionID: first.id, expectedVersion: profile.version
    )
    #expect(restored.canonical == accepted)
    #expect(try store.record(worldID: world.id, id: record.id).state == "draft")
  }

  @Test func invalidInheritanceSchemaChangesAndCrossWorldReferencesRollBack() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Foreign")
    let parent = try store.saveEntityType(worldID: world.id, name: "Creature", fields: [strength])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Dragon", parentTypeID: parent.id, fields: [])
    let record = try store.createTypedEntity(worldID: world.id, typeID: child.id, title: "Ember")
    let profile = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id, values: ["strength": .number(12)],
      expectedVersion: 1)
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, id: parent.id, expectedVersion: parent.version, name: parent.name,
        parentTypeID: child.id, fields: parent.fields)
    }
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, id: parent.id, expectedVersion: parent.version, name: parent.name,
        fields: [])
    }
    #expect(try store.entityType(worldID: world.id, id: parent.id) == parent)
    #expect(try store.entityProfile(worldID: world.id, recordID: record.id) == profile)
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: other.id, name: "Foreign child", parentTypeID: parent.id, fields: [])
    }
    #expect(throws: SynthesisError.self) {
      try store.entityProfile(worldID: other.id, recordID: record.id)
    }
    let foreign = try store.createRecord(worldID: other.id, title: "Secret", kind: "entity")
    let home = EntityField(key: "home", label: "Home", kind: .entity)
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, name: "Bad reference", fields: [home],
        defaults: ["home": .entity(foreign.id)])
    }
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, name: "Bad condition",
        fields: [
          home,
          EntityField(
            key: "secret", label: "Secret",
            condition: .init(field: "home", equals: .entity(foreign.id))),
        ])
    }
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, name: "Recursive",
        fields: [
          EntityField(key: "a", label: "A", kind: .formula, formula: "b + 1"),
          EntityField(key: "b", label: "B", kind: .formula, formula: "a + 1"),
        ])
    }
  }

  @Test func templatesCreateIndependentDraftsAndRetainVersionsAndArchives() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let type = try store.saveEntityType(
      worldID: world.id, name: "Kingdom", fields: [EntityField(key: "culture", label: "Culture")])
    var template = try store.saveEntityTemplate(
      worldID: world.id, typeID: type.id, name: "Coastal kingdom",
      body: "A kingdom beside an unnamed sea.", values: ["culture": .text("Seafarers")])
    let first = try store.createTypedEntity(
      worldID: world.id, typeID: type.id, title: "Eastwatch", templateID: template.id)
    let second = try store.createTypedEntity(
      worldID: world.id, typeID: type.id, title: "Northwatch", templateID: template.id)
    #expect(first.id != second.id && first.body == second.body && first.state == "draft")
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: first.id, typeID: type.id,
      values: ["culture": .text("Cartographers")], expectedVersion: 1)
    #expect(
      try store.entityProfile(worldID: world.id, recordID: second.id)?.values["culture"]
        == .text("Seafarers"))
    template = try store.saveEntityTemplate(
      worldID: world.id, id: template.id, expectedVersion: template.version, typeID: type.id,
      name: template.name, body: "A revised starting point.", values: template.values)
    #expect(try store.entityTemplateHistory(worldID: world.id, templateID: template.id).count == 2)
    #expect(try store.record(worldID: world.id, id: first.id).body == first.body)
    try store.setEntityTemplateArchived(
      worldID: world.id, id: template.id, archived: true, expectedVersion: template.version)
    #expect(try store.entityTemplates(worldID: world.id).isEmpty)
    #expect(throws: SynthesisError.self) {
      try store.createTypedEntity(
        worldID: world.id, typeID: type.id, title: "Blocked", templateID: template.id)
    }
    try store.setEntityTemplateArchived(
      worldID: world.id, id: template.id, archived: false, expectedVersion: template.version + 1)
    #expect(try store.entityTemplateHistory(worldID: world.id, templateID: template.id).count == 4)
    try store.setEntityTypeArchived(
      worldID: world.id, id: type.id, archived: true, expectedVersion: type.version)
    #expect(try store.entityTypes(worldID: world.id).isEmpty)
    #expect(try store.entityProfileReview(worldID: world.id, recordID: second.id) != nil)
    #expect(throws: SynthesisError.self) {
      try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Blocked")
    }
    try store.setEntityTypeArchived(
      worldID: world.id, id: type.id, archived: false, expectedVersion: type.version + 1)
    #expect(try store.entityTypes(worldID: world.id).count == 1)
  }

  @Test func denseFormulaGraphHasStableValuesAndMissingInputsStayUnknown() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Arithmetic")
    var fields = [
      EntityField(key: "a", label: "A", kind: .number),
      EntityField(key: "b", label: "B", kind: .number),
    ]
    for index in 0..<60 {
      let left = index == 0 ? "a" : "value_\(index - 1)"
      let right = index < 2 ? "b" : "value_\(index - 2)"
      fields.append(
        EntityField(
          key: "value_\(index)", label: "Value \(index)", kind: .formula,
          formula: "\(left) + \(right)"))
    }
    let type = try store.saveEntityType(
      worldID: world.id, name: "Computed", fields: fields,
      defaults: ["a": .number(1), "b": .number(1)])
    let record = try store.createTypedEntity(
      worldID: world.id, typeID: type.id, title: "A test of dependencies")
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    if case .number(let result) = review.snapshot.values["value_59"] {
      #expect(result > 1_000_000)
    } else {
      Issue.record("Dense dependency computation was unavailable")
    }
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: type.id, values: ["a": .unknown],
      expectedVersion: 1)
    #expect(
      try store.entityProfileReview(worldID: world.id, recordID: record.id)?.snapshot.values[
        "value_59"] == .unknown)
  }
  @Test func multiValueFieldsInheritPersistAndRemainScopedThroughCanonAndImport() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    let first = try store.createRecord(worldID: world.id, title: "Tidekeepers", kind: "entity")
    let second = try store.createRecord(
      worldID: world.id, title: "Old Cartographers", kind: "entity")
    let foreign = try store.createRecord(
      worldID: other.id, title: "Foreign society", kind: "entity")
    let fields = [
      EntityField(
        key: "languages", label: "Languages", kind: .selections,
        options: ["Coastal", "High speech", "Old tide"]),
      EntityField(key: "allies", label: "Allies", kind: .entities),
    ]
    let parent = try store.saveEntityType(
      worldID: world.id, name: "Person", fields: fields,
      defaults: [
        "languages": .selections(["Coastal"]), "allies": .entities([first.id, second.id]),
      ])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Navigator", parentTypeID: parent.id, fields: [],
      defaults: ["languages": .selections(["Coastal", "Old tide"])])
    let record = try store.createTypedEntity(worldID: world.id, typeID: child.id, title: "Mira")
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(review.snapshot.values["languages"] == .selections(["Coastal", "Old tide"]))
    #expect(review.snapshot.values["allies"] == .entities([first.id, second.id]))
    for invalid: [String: EntityValue] in [
      ["allies": .entities([foreign.id])], ["allies": .entities([first.id, first.id])],
      ["languages": .selections(["Unknown language"])],
      ["languages": .selections(["Coastal", "Coastal"])],
    ] {
      #expect(throws: SynthesisError.self) {
        try store.saveEntityProfile(
          worldID: world.id, recordID: record.id, typeID: child.id, values: invalid,
          expectedVersion: 1)
      }
    }
    #expect(throws: SynthesisError.self) {
      try store.saveEntityType(
        worldID: world.id, name: "Bad list formula", parentTypeID: child.id,
        fields: [
          EntityField(key: "total", label: "Total", kind: .formula, formula: "languages + 1")
        ])
    }
    let accepted = try store.acceptEntityProperties(
      worldID: world.id, recordID: record.id, confirmedProfileID: review.profile.id,
      expectedRevision: review.revision)
    try store.archiveRecord(worldID: world.id, id: second.id)
    let scoped = try store.entityPropertyText(
      worldID: world.id, recordID: record.id, allowedIDs: [record.id, first.id])
    #expect(
      scoped.contains("Tidekeepers") && !scoped.contains("Old Cartographers")
        && !scoped.contains(second.id))
    let archive = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchive(archive)
    let copiedRecord = try #require(
      try store.records(worldID: copy.id).first { $0.title == "Mira" })
    let copied = try #require(
      try store.entityProfileReview(worldID: copy.id, recordID: copiedRecord.id))
    #expect(
      copied.isCanon && copied.snapshot.values["languages"] == review.snapshot.values["languages"])
    if case .entities(let ids) = copied.snapshot.values["allies"] {
      #expect(ids.count == 2 && !ids.contains(first.id) && !ids.contains(second.id))
      #expect(try ids.contains { try store.isArchived(worldID: copy.id, recordID: $0) })
    } else {
      Issue.record("Multi-entity reference did not survive import")
    }
    let cleared = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id,
      values: ["languages": .selections([]), "allies": .entities([])],
      expectedVersion: accepted.version)
    #expect(cleared.canonical == accepted.canonical)
    let current = try #require(
      try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(current.snapshot.values["allies"] == .entities([]) && !current.isCanon)
    #expect(try store.search(worldID: world.id, query: "Old tide").contains { $0.id == record.id })
    #expect(
      try store.exportRecordMarkdown(worldID: world.id, recordID: record.id).content.contains(
        "Tidekeepers"))
  }

}
