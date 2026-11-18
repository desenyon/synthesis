import SynthesisCore
import Testing

struct EntityProfileCompletionTests {
  @Test func suggestionsRespectConditionsDefaultsAndDeliberatelyUnknownValues() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Glass Coast")
    let parent = try store.saveEntityType(
      worldID: world.id, name: "Person",
      fields: [
        EntityField(key: "living", label: "Living", kind: .boolean),
        EntityField(key: "homeland", label: "Homeland"),
      ], defaults: ["living": .boolean(true), "homeland": .text("Coast")])
    let type = try store.saveEntityType(
      worldID: world.id, name: "Cartographer", parentTypeID: parent.id,
      fields: [
        EntityField(key: "origin", label: "Origin"),
        EntityField(key: "vocation", label: "Vocation"),
        EntityField(key: "company", label: "Company", kind: .entities),
        EntityField(
          key: "death", label: "Cause of death",
          condition: .init(field: "living", equals: .boolean(false))),
        EntityField(key: "weight", label: "Weight", kind: .formula, formula: "2 + 1"),
      ])
    let mira = try store.createRecord(
      worldID: world.id, title: "Mira", body: "Mira maps the coast.", kind: "entity")
    let profile = try store.saveEntityProfile(
      worldID: world.id, recordID: mira.id, typeID: type.id,
      values: ["origin": .unknown, "company": .entities([])], expectedVersion: nil)
    let initial = try #require(try store.entityProfileReview(worldID: world.id, recordID: mira.id))
    #expect(initial.suggestedFields.map(\.key) == ["vocation"])
    #expect(try store.entityProfile(worldID: world.id, recordID: mira.id) == profile)

    let accepted = try store.acceptEntityProperties(
      worldID: world.id, recordID: mira.id, confirmedProfileID: initial.profile.id,
      expectedRevision: initial.revision)
    _ = try store.saveEntityProfile(
      worldID: world.id, recordID: mira.id, typeID: type.id,
      values: accepted.values.merging(["vocation": .text("Chartmaker"), "living": .boolean(false)])
      {
        _, draft in draft
      }, expectedVersion: accepted.version)
    let revised = try #require(try store.entityProfileReview(worldID: world.id, recordID: mira.id))
    #expect(revised.suggestedFields.map(\.key) == ["death"])
    #expect(revised.profile.canonical == initial.snapshot)
    #expect(try store.record(worldID: world.id, id: mira.id) == mira)
  }
}
