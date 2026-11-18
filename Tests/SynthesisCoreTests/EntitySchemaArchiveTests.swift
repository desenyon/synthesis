import Foundation
import Testing

@testable import SynthesisCore

struct EntitySchemaArchiveTests {
  @Test func structuredWorldRoundTripRemapsEveryReferenceAndRebuildsSearch() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let sea = try store.createRecord(worldID: world.id, title: "The Glass Sea", kind: "entity")
    let parent = try store.saveEntityType(
      worldID: world.id, name: "Person", fields: [EntityField(key: "ancestry", label: "Ancestry")],
      defaults: ["ancestry": .text("Moonfarer")])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Navigator", parentTypeID: parent.id,
      fields: [EntityField(key: "home", label: "Home", kind: .entity)],
      defaults: ["home": .entity(sea.id)])
    let template = try store.saveEntityTemplate(
      worldID: world.id, typeID: child.id, name: "Coastal navigator",
      body: "The sea is her compass.", values: ["home": .entity(sea.id)])
    let mira = try store.createTypedEntity(
      worldID: world.id, typeID: child.id, title: "Mira", templateID: template.id)
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: mira.id))
    _ = try store.acceptEntityProperties(
      worldID: world.id, recordID: mira.id, confirmedProfileID: review.profile.id,
      expectedRevision: review.revision)
    let data = try store.exportWorldArchive(worldID: world.id)
    let copy = try store.importWorldArchive(data)
    let records = try store.records(worldID: copy.id)
    let copiedMira = try #require(records.first { $0.title == "Mira" })
    let copiedSea = try #require(records.first { $0.title == "The Glass Sea" })
    let copiedReview = try #require(
      try store.entityProfileReview(worldID: copy.id, recordID: copiedMira.id))
    #expect(copiedMira.id != mira.id && copiedReview.profile.typeID != child.id)
    #expect(copiedReview.snapshot.values["home"] == .entity(copiedSea.id))
    #expect(copiedReview.profile.canonical?.values["home"] == .entity(copiedSea.id))
    #expect(copiedReview.isCanon)
    #expect(try store.entityProfileHistory(worldID: copy.id, recordID: copiedMira.id).count == 2)
    #expect(try store.entityTypes(worldID: copy.id).count == 2)
    let copiedTemplate = try #require(try store.entityTemplates(worldID: copy.id).first)
    #expect(copiedTemplate.values["home"] == .entity(copiedSea.id))
    #expect(
      try store.entityTemplateHistory(worldID: copy.id, templateID: copiedTemplate.id).count == 1)
    #expect(try store.search(worldID: copy.id, query: "Moonfarer").map(\.id) == [copiedMira.id])
    let markdown = try store.exportRecordMarkdown(worldID: copy.id, recordID: copiedMira.id).content
    #expect(
      markdown.contains("Working property draft") && markdown.contains("Accepted property canon"))
    let json = try #require(
      try JSONSerialization.jsonObject(with: store.exportWorld(copy.id)) as? [String: Any])
    #expect((json["entityProfiles"] as? [[String: String]])?.count == 1)
    #expect((json["entityTemplateHistory"] as? [[String: String]])?.count == 1)
    let scoped = try store.entityPropertyText(
      worldID: copy.id, recordID: copiedMira.id, allowedIDs: [copiedMira.id])
    #expect(
      !scoped.contains("The Glass Sea") && !scoped.contains(copiedSea.id)
        && scoped.contains("Excluded entity"))
    #expect(
      try store.entityPropertyText(worldID: copy.id, recordID: copiedMira.id).contains(
        "The Glass Sea"))
  }

  @Test func malformedImportedSchemasAndMissingLegacyPrimaryKeysRollBack() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    let secret = try store.createRecord(worldID: other.id, title: "Private", kind: "entity")
    let type = try store.saveEntityType(
      worldID: world.id, name: "Navigator",
      fields: [EntityField(key: "home", label: "Home", kind: .entity)])
    _ = try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Mira")
    let archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    let count = try store.worlds().count
    var invalid = archive
    invalid.tables["entity_profiles"]?[0]["values_json"] = try schemaJSON([
      "home": EntityValue.entity(secret.id)
    ])
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
    invalid = archive
    invalid.tables["entity_types"]?[0]["parent_type_id"] = type.id
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
    invalid = archive
    invalid.tables["entity_types"]?[0]["fields_json"] = "{}"
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
    invalid = archive
    invalid.tables["records"]?[0].removeValue(forKey: "id")
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
    invalid = archive
    invalid.tables["entity_template_history"] = [
      [
        "id": UUID().uuidString, "world_id": world.id, "template_id": secret.id, "version": "1",
        "snapshot_json": "{}", "created_at": timestamp(),
      ]
    ]
    #expect(throws: SynthesisError.self) {
      try store.importWorldArchive(JSONEncoder().encode(invalid))
    }
    #expect(try store.worlds().count == count)
  }

  @Test func versionNineWorldsImportWithoutInventedProfilesOrLostLore() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Old world")
    let record = try store.createRecord(
      worldID: world.id, title: "An old page", body: "Every word survives.", kind: "entity",
      category: "Species")
    var archive = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    archive.version = 9
    for key in [
      "entity_types", "entity_profiles", "entity_profile_history", "entity_type_history",
      "entity_templates", "entity_template_history", "conversation_branches",
      "conversation_message_origins", "prompt_recipes",
    ] {
      archive.tables.removeValue(forKey: key)
    }
    let copy = try store.importWorldArchive(JSONEncoder().encode(archive))
    let copied = try #require(try store.records(worldID: copy.id).first)
    #expect(copied.body == record.body && copied.category == "Species")
    #expect(try store.entityTypes(worldID: copy.id).isEmpty)
    #expect(try store.entityProfile(worldID: copy.id, recordID: copied.id) == nil)
  }
  @Test func longWorkingPropertiesCannotTruncateAcceptedCanonOutOfAssistantContext() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let secret = try store.createRecord(
      worldID: world.id, title: "The Excluded Harbour", body: "PRIVATE HARBOR LORE", kind: "entity")
    let fields =
      (0..<5).map { EntityField(key: "detail_\($0)", label: "Detail \($0)") }
      + [EntityField(key: "home", label: "Home", kind: .entity)]
    var defaults = Dictionary(
      uniqueKeysWithValues: (0..<5).map {
        ("detail_\($0)", EntityValue.text("Accepted detail \($0)"))
      })
    defaults["home"] = .entity(secret.id)
    let type = try store.saveEntityType(
      worldID: world.id, name: "Navigator", fields: fields, defaults: defaults)
    let record = try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Mira")
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    _ = try store.acceptEntityProperties(
      worldID: world.id, recordID: record.id, confirmedProfileID: review.profile.id,
      expectedRevision: review.revision)
    for index in 0..<5 {
      defaults["detail_\(index)"] = .text(
        String(repeating: "Unapproved draft detail \(index). ", count: 100))
    }
    _ = try store.saveEntityType(
      worldID: world.id, id: type.id, expectedVersion: type.version, name: type.name,
      fields: type.fields, defaults: defaults)
    var options = AssistantContextOptions()
    options.scope = .attachments
    options.recordIDs = [record.id]
    options.excludedRecordIDs = [secret.id]
    let context = try store.assistantContext(
      worldID: world.id, prompt: "Describe Mira", options: options)
    #expect(context.lore.contains("Accepted property canon (separate frozen snapshot):"))
    #expect(context.lore.contains("Accepted detail 4"))
    #expect(
      context.lore.contains("Working property draft:")
        && context.lore.contains("Unapproved draft detail"))
    #expect(context.lore.contains("[Truncated:"))
    #expect(
      !context.lore.contains(secret.id) && !context.lore.contains("The Excluded Harbour")
        && !context.lore.contains("PRIVATE HARBOR LORE"))
    let text = try store.entityPropertyText(
      worldID: world.id, recordID: record.id, allowedIDs: [record.id], limit: 4000)
    #expect(
      text.count <= 4000 && text.contains("Accepted detail 4")
        && text.contains("Working property draft:"))
    #expect(
      try store.entityProfileReview(worldID: world.id, recordID: record.id)?.profile.canonical
        == review.snapshot)
  }

  @Test func oversizedRetiredSchemaTemplateAndPropertyPayloadsAreRejectedAtomically() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let type = try store.saveEntityType(
      worldID: world.id, name: "Person", fields: [EntityField(key: "notes", label: "Notes")])
    _ = try store.saveEntityTemplate(
      worldID: world.id, typeID: type.id, name: "Starting profile", body: "Original prose.")
    _ = try store.createTypedEntity(worldID: world.id, typeID: type.id, title: "Mira")
    let original = try JSONDecoder().decode(
      WorldArchive.self, from: store.exportWorldArchive(worldID: world.id))
    let count = try store.worlds().count
    for attack in 0..<8 {
      var archive = original
      if attack < 3 {
        var snapshot = try schemaDecode(
          EntityTemplate.self, archive.tables["entity_template_history"]![0]["snapshot_json"]!)
        if attack == 0 { snapshot.name = String(repeating: "x", count: 121) }
        if attack == 1 { snapshot.body = String(repeating: "x", count: 200_001) }
        if attack == 2 { snapshot.description = String(repeating: "x", count: 4001) }
        archive.tables["entity_template_history"]?[0]["snapshot_json"] = try schemaJSON(snapshot)
      } else if attack < 7 {
        var snapshot = try schemaDecode(
          EntityType.self, archive.tables["entity_type_history"]![0]["snapshot_json"]!)
        if attack == 3 { snapshot.description = String(repeating: "x", count: 4001) }
        if attack == 4 {
          snapshot.fields = (0..<101).map { EntityField(key: "field_\($0)", label: "Field \($0)") }
        }
        if attack == 5 { snapshot.fields[0].note = String(repeating: "x", count: 2001) }
        if attack == 6 { snapshot.fields[0].options = Array(repeating: "x", count: 101) }
        archive.tables["entity_type_history"]?[0]["snapshot_json"] = try schemaJSON(snapshot)
      } else {
        var snapshot = try schemaDecode(
          EntityProfile.self, archive.tables["entity_profile_history"]![0]["snapshot_json"]!)
        snapshot.values["notes"] = .text(String(repeating: "x", count: 20_001))
        archive.tables["entity_profile_history"]?[0]["snapshot_json"] = try schemaJSON(snapshot)
      }
      #expect(throws: SynthesisError.self) {
        try store.importWorldArchive(JSONEncoder().encode(archive))
      }
      #expect(try store.worlds().count == count)
    }
  }

  @Test func inheritedMediaCannotMakeAnUnportableAcceptedSnapshot() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let map = EntityField(key: "map", label: "Map", kind: .media)
    let parent = try store.saveEntityType(worldID: world.id, name: "Person", fields: [map])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Navigator", parentTypeID: parent.id,
      fields: [
        EntityField(key: "portrait", label: "Portrait", kind: .media),
        EntityField(key: "study", label: "Study", kind: .media),
      ])
    let record = try store.createTypedEntity(worldID: world.id, typeID: child.id, title: "Mira")
    let firstReview = try #require(
      try store.entityProfileReview(worldID: world.id, recordID: record.id))
    let accepted = try store.acceptEntityProperties(
      worldID: world.id, recordID: record.id, confirmedProfileID: firstReview.profile.id,
      expectedRevision: firstReview.revision)

    // Each 6 MB PNG fits the per-image limit and takes 8 MB before JSON metadata.
    // Two overrides and one inherited value each fit their separate drafts.
    let image = Self.maximumSizePropertyImage()
    let working = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id,
      values: ["portrait": image, "study": image], expectedVersion: accepted.version)
    try store.saveEntityType(
      worldID: world.id, id: parent.id, expectedVersion: parent.version, name: parent.name,
      fields: [map], defaults: ["map": image])

    let oversized = try #require(
      try store.entityProfileReview(worldID: world.id, recordID: record.id))
    #expect(oversized.snapshot.values.count == 3)
    #expect(throws: SynthesisError.self) {
      try store.acceptEntityProperties(
        worldID: world.id, recordID: record.id, confirmedProfileID: oversized.profile.id,
        expectedRevision: oversized.revision)
    }
    let unchanged = try store.entityProfile(worldID: world.id, recordID: record.id)
    #expect(unchanged?.version == working.version && unchanged?.canonical == firstReview.snapshot)
    let history = try store.entityProfileHistory(worldID: world.id, recordID: record.id)
    #expect(history.map { $0.profile.version } == [working.version, accepted.version, 1])
  }

  private static func maximumSizePropertyImage() -> EntityValue {
    let original = RecordArtworkTests.png
    var data = Data(original.dropLast(12))
    // Insert a valid tEXt chunk before IEND. The pixels stay 1×1, and the fixed chunk
    // length and CRC-32 below cover Comment, its NUL separator, and 5,999,912 "x" bytes.
    data.append(contentsOf: [0x00, 0x5b, 0x8d, 0x30])
    data.append(contentsOf: "tEXtComment\0".utf8)
    data.append(Data(repeating: 0x78, count: 5_999_912))
    data.append(contentsOf: [0xc4, 0xac, 0xc7, 0xd2])
    data.append(contentsOf: original.suffix(12))
    return .media(name: "reference.png", mime: "image/png", base64: data.base64EncodedString())
  }

  @Test func schemaImageExportIncludesInheritedTemplateAndAcceptedMediaWithinOneWorld() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Aster")
    let other = try store.createWorld(name: "Other")
    let image = EntityValue.media(
      name: "study.png", mime: "image/png", base64: RecordArtworkTests.png.base64EncodedString())
    let field = EntityField(key: "reference", label: "Reference", kind: .media)
    var type = try store.saveEntityType(
      worldID: world.id, name: "Person", fields: [field], defaults: ["reference": image])
    let child = try store.saveEntityType(
      worldID: world.id, name: "Navigator", parentTypeID: type.id, fields: [])
    let template = try store.saveEntityTemplate(
      worldID: world.id, typeID: child.id, name: "Portrait profile", values: ["reference": image])
    let record = try store.createTypedEntity(
      worldID: world.id, typeID: child.id, title: "Mira", templateID: template.id)
    let review = try #require(try store.entityProfileReview(worldID: world.id, recordID: record.id))
    let accepted = try store.acceptEntityProperties(
      worldID: world.id, recordID: record.id, confirmedProfileID: review.profile.id,
      expectedRevision: review.revision)
    #expect(
      try store.entityPropertyImages(worldID: world.id).map(\.data) == [RecordArtworkTests.png])
    #expect(try store.entityPropertyImages(worldID: other.id).isEmpty)
    type = try store.saveEntityType(
      worldID: world.id, id: type.id, expectedVersion: type.version, name: type.name,
      fields: type.fields)
    try store.setEntityTemplateArchived(
      worldID: world.id, id: template.id, archived: true, expectedVersion: template.version)
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: record.id, typeID: child.id, values: ["reference": .unknown],
      expectedVersion: accepted.version)
    // The old image is still accepted property canon, even though the working profile is blank.
    #expect(
      try store.entityPropertyImages(worldID: world.id).map(\.data) == [RecordArtworkTests.png])
    try store.archiveRecord(worldID: world.id, id: record.id)
    #expect(try store.entityPropertyImages(worldID: world.id).isEmpty)
    #expect(
      try store.entityPropertyImages(worldID: world.id, includingArchived: true).map(\.data) == [
        RecordArtworkTests.png
      ])
  }

}
