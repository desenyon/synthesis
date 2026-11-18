import AppKit
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct EditorReferenceTests {
  @Test func composerDisplaysTypedAndLegacyLinksAsTokensAndKeepsTheirAddresses() throws {
    let destination = "synthesis://reference/canvasImage/image_A?world=world-A&container=board-A"
    let markdown =
      #"See [Old record \](synthesis://record/ABC-123) and "#
      + #"[Figure \[A\] \\ north](\#(destination))."#
    let shown = MentionCodec.attributed(markdown, base: [:], accent: .blue, soft: .gray)
    #expect(shown.string == #"See Old record \ and Figure [A] \ north."#)
    let label = (shown.string as NSString).range(of: "Figure")
    let address = try #require(
      shown.attribute(MentionCodec.key, at: label.location, effectiveRange: nil) as? String)
    #expect(address == destination)
    #expect(MentionCodec.markdown(shown) == markdown)
  }

  @Test func invalidTypedLinkIsNotPresentedAsAReference() {
    let markdown = "[Unscoped source](synthesis://reference/event/event-A)"
    let shown = MentionCodec.attributed(markdown, base: [:], accent: .blue, soft: .gray)
    #expect(shown.string == markdown)
    #expect(shown.attribute(MentionCodec.key, at: 0, effectiveRange: nil) == nil)
  }

  @Test func nativeInsertionReplacesSelectionAndPersistsTheLinkedLabelThroughRTF() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let worldID = studio.worldID
    let record = try store.createRecord(
      worldID: worldID, title: "Writing", body: "Before room after")
    let sourceRecord = try store.createRecord(worldID: worldID, title: "Figure [A]")
    let address = WorldReference(worldID: worldID, kind: .record, id: sourceRecord.id)
    let source = try store.resolveReference(address, worldID: worldID)
    let handle = EditorHandle()
    var body = record.body
    var rtf: String?
    var opened: URL?
    let editor = RichDocumentEditor(
      id: record.id, body: body, rtf: nil, t: studio.t, reloadToken: 0, handle: handle,
      openLink: { opened = $0 },
      changed: {
        body = $0
        rtf = $1
      })
    let coordinator = editor.makeCoordinator()
    let scroll = editor.makeEditor(coordinator: coordinator)
    let view = try #require(scroll.documentView as? NSTextView)
    view.setSelectedRange(NSRange(location: 7, length: 4))
    handle.undoManager.beginUndoGrouping()
    let inserted = handle.insertReference(source)
    handle.undoManager.endUndoGrouping()
    #expect(inserted && body == "Before Figure [A] after")
    #expect(view.selectedRange() == NSRange(location: 17, length: 0))
    #expect(view.typingAttributes[.link] == nil)
    let encoded = try #require(rtf)
    let data = try #require(Data(base64Encoded: encoded))
    let restored = try #require(NSAttributedString(rtf: data, documentAttributes: nil))
    let value = try #require(restored.attribute(.link, at: 7, effectiveRange: nil))
    let restoredAddress = (value as? URL)?.absoluteString ?? (value as? String)
    #expect(restoredAddress == address.url.absoluteString)
    #expect(restored.attribute(.link, at: 17, effectiveRange: nil) == nil)
    #expect(coordinator.textView(view, clickedOnLink: value, at: 7))
    #expect(opened == address.url)
    let saved = try store.saveRecord(
      worldID: worldID, id: record.id, version: record.version, title: record.title,
      body: body, rtf: encoded)
    let backlinks = try store.recordBacklinks(worldID: worldID, recordID: sourceRecord.id)
    #expect(backlinks.linked.map(\.id) == [saved.id])
    #expect(backlinks.mentioned.isEmpty)
    let markdown = try store.exportRecordMarkdown(worldID: worldID, recordID: saved.id).content
    #expect(markdown.contains(#"[Figure \[A\]](\#(address.url.absoluteString))"#))
    #expect(saved.canonical == nil)
    _ = try store.promote(
      worldID: worldID, id: saved.id, version: saved.version, confirmation: saved.id)
    try checkImportedLink(store: store, worldID: worldID)
    #expect(handle.undoManager.canUndo)
    handle.undoManager.undo()
    #expect(view.string == record.body)
    #expect(view.attributedString().attribute(.link, at: 7, effectiveRange: nil) == nil)
  }

  private func checkImportedLink(store: WorkspaceStore, worldID: String) throws {
    let archive = try store.exportWorldArchive(worldID: worldID)
    let copy = try store.importWorldArchive(archive)
    let records = try store.records(worldID: copy.id)
    let page = try #require(records.first { $0.title == "Writing" })
    let source = try #require(records.first { $0.title == "Figure [A]" })
    let exported = try store.exportRecordMarkdown(worldID: copy.id, recordID: page.id).content
    let references = WorkspaceStore.worldReferences(in: exported)
    #expect(references == [WorldReference(worldID: copy.id, kind: .record, id: source.id)])
    let address = try #require(references.first)
    #expect(try store.resolveReference(address, worldID: copy.id).title == "Figure [A]")
    let canonical = try #require(page.canonical)
    let accepted = try JSONDecoder().decode(LoreRecord.self, from: Data(canonical.utf8))
    try checkRichLink(accepted.rtf, matches: address)
    let history = try store.history(worldID: copy.id, id: page.id)
    #expect(history.count == 3)
    for revision in history where revision.version > 1 {
      try checkRichLink(revision.snapshot.rtf, matches: address)
      if let canonical = revision.snapshot.canonical {
        let snapshot = try JSONDecoder().decode(LoreRecord.self, from: Data(canonical.utf8))
        try checkRichLink(snapshot.rtf, matches: address)
      }
    }
  }

  private func checkRichLink(_ richText: String?, matches address: WorldReference) throws {
    let encoded = try #require(richText)
    let data = try #require(Data(base64Encoded: encoded))
    let restored = try #require(NSAttributedString(rtf: data, documentAttributes: nil))
    let value = restored.attribute(.link, at: 7, effectiveRange: nil)
    let destination = (value as? URL)?.absoluteString ?? (value as? String)
    #expect(destination == address.url.absoluteString)
  }
}
