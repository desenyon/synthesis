import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct LegacyComposerReferenceTests {
  @Test func addingABracketedRecordCreatesARoundTrippableScopedToken() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: #"Private [Annex] \ crossing"#)
    try studio.reload()
    studio.draft = "Compare"
    studio.reference(record)

    let address = WorldReference(worldID: studio.worldID, kind: .record, id: record.id)
    #expect(WorkspaceStore.worldReferences(in: studio.draft) == [address])
    let shown = MentionCodec.attributed(studio.draft, base: [:], accent: .blue, soft: .gray)
    #expect(shown.string == "Compare \(record.title) ")
    #expect(MentionCodec.markdown(shown) == studio.draft)
    #expect(try store.preference("composer:\(studio.worldID)") == studio.draft)
  }
}
