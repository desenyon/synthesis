import AppKit
import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct WorkspaceTests {
  @Test func acceptingWorkspaceChangesRefreshesHistoryAndSelectsTheCreatedMap() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let initial = studio.worldRevision
    let proposal = try #require(
      try store.stageProposal(
        worldID: studio.worldID, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_branch", "title": "The long winter"],
            ["action": "add_event", "title": "First snowfall", "lane": "The long winter"],
            ["action": "create_map", "title": "Northern coast"],
          ]
        ]))
    #expect(proposal.changes.count == 3)
    studio.resolveAll(proposal, accept: true)
    for _ in 0..<100 where studio.reviewingProposal { try await Task.sleep(for: .milliseconds(10)) }
    #expect(!studio.reviewingProposal)
    #expect(studio.error == nil, "\(studio.error ?? "")")
    #expect(studio.worldRevision > initial)
    #expect(try store.events(worldID: studio.worldID).count == 1)
    let map = try #require(try store.boards(worldID: studio.worldID, kind: "atlas").first)
    #expect(studio.mapBoardID == map.id)
    #expect(studio.pendingProposals.isEmpty)
    #expect(studio.records.contains { $0.title == "First snowfall" && $0.state == "draft" })
  }

  @Test func sectionChildrenDoNotInflateCharacterNavigation() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let parent = try store.createRecord(
      worldID: studio.worldID, title: "Mira", kind: "entity", category: "Characters")
    for n in 1...3 {
      try store.createRecordSection(
        worldID: studio.worldID, parentID: parent.id, title: "Section \(n)")
    }
    try studio.reload()
    #expect(studio.records.count == 4)
    #expect(studio.sectionParents.count == 3)
    #expect(studio.topLevelRecords.filter { $0.category == "Characters" }.count == 1)
  }

  @Test func assistanceModePreservesWorkspaceAndEditorGuard() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.destination = .library
    let record = try store.createRecord(worldID: studio.worldID, title: "A page")
    studio.selectedRecord = record
    studio.editorSave = { false }
    studio.setMode(.manual)
    #expect(studio.destination == .library && studio.selectedRecord?.id == record.id)
    #expect(!studio.flushEditor())
    #expect(try store.preference("mode") == "manual")
    studio.setMode(.assisted)
    #expect(studio.destination == .library && !studio.flushEditor())
  }
  @Test func companionConversationSwitchKeepsBoardSaveProtection() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let chat = try store.createConversation(worldID: studio.worldID)
    studio.destination = .canvas
    var succeeds = true
    studio.editorSave = { succeeds }
    studio.openChat(chat, keepWorkspace: true)
    #expect(studio.destination == .canvas && studio.conversationID == chat.id)
    studio.newChat(keepWorkspace: true)
    #expect(studio.destination == .canvas && studio.editorSave != nil)
    succeeds = false
    studio.navigate(.library)
    #expect(studio.destination == .canvas)
    studio.openChat(chat, keepWorkspace: true)
    #expect(studio.conversationID == nil)
  }
  @Test func pendingDraftSurvivesImmediateWorldSwitch() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let original = studio.worldID
    let other = try store.createWorld(name: "Other")
    studio.pendingComposer = (original, "Last keystrokes")
    studio.switchWorld(other.id)
    #expect(try store.preference("composer:\(original)") == "Last keystrokes")
    #expect(studio.draft.isEmpty)
    studio.switchWorld(original)
    #expect(studio.draft == "Last keystrokes")
  }
  @Test func openingARecordKeepsTheWorkspaceItCameFrom() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    try studio.reload()
    studio.navigate(.knowledge)
    studio.openRecord(record)
    #expect(studio.destination == .knowledge && studio.selectedRecord?.id == record.id)
    studio.closeRecord()
    #expect(studio.destination == .knowledge && studio.selectedRecord == nil)
    #expect(try store.preference("destination") == Destination.knowledge.rawValue)
  }
  @Test func archivingFromTheStudioIsUndoable() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    try studio.reload()
    studio.openRecord(record)
    studio.archive(record)
    #expect(studio.records.isEmpty && studio.selectedRecord == nil)
    #expect(studio.toast?.actionTitle == "Undo")
    studio.toast?.action?()
    #expect(studio.records.map(\.id) == [record.id])
    let chat = try store.createConversation(worldID: studio.worldID, title: "Tides")
    try studio.reload()
    studio.openChat(chat)
    studio.archive(chat)
    #expect(studio.conversations.isEmpty && studio.conversationID == nil)
    studio.toast?.action?()
    #expect(studio.conversations.map(\.id) == [chat.id])
  }
  @Test func savedAssistantOutputIsAnAIProposedDraftNeverCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let chat = try store.createConversation(worldID: studio.worldID)
    let message = try store.appendMessage(
      worldID: studio.worldID, conversationID: chat.id, role: "assistant",
      body: "## The Tide Ledger\n\nA record of every crossing.", state: "complete")
    studio.saveResponse(message)
    let saved = try #require(studio.selectedRecord)
    #expect(saved.title == "The Tide Ledger" && saved.origin == "ai-proposed")
    #expect(saved.state == "draft" && saved.canonical == nil)
  }
  @Test func sampleWorldIsIdempotentAndLeavesOtherWorldsAlone() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let mine = studio.worldID
    _ = try store.createRecord(worldID: mine, title: "My page", body: "Untouched")
    studio.loadSample()
    let sample = studio.worldID
    #expect(sample != mine && studio.world?.demo == true)
    let count = studio.records.count
    #expect(try count >= 9 && store.relations(worldID: sample).count == 7)
    #expect(studio.records.allSatisfy { $0.state != "canon" })
    studio.switchWorld(mine)
    studio.loadSample()
    #expect(studio.worldID == sample && studio.records.count == count)
    #expect(try store.worlds().count == 2)
    #expect(try store.records(worldID: mine).map(\.body) == ["Untouched"])
  }
  @Test func markdownBlocksCoverListsQuotesTablesAndFencedCode() {
    let blocks = MarkdownBlock.parse(
      """
      # Title
      Intro line
      still intro

      - one
        wrapped
      - two
      1. first
      > quoted
      ```
      code

      after blank
      ```
      | A | B |
      | --- | --- |
      | 1 | 2 |
      ---
      """)
    #expect(blocks.count == 7)
    #expect(blocks[0] == .heading(level: 1, text: "Title"))
    #expect(blocks[1] == .paragraph("Intro line\nstill intro"))
    #expect(
      blocks[2]
        == .list(
          ordered: false,
          items: [
            .init(indent: 0, marker: "•", text: "one wrapped"),
            .init(indent: 0, marker: "•", text: "two"),
            .init(indent: 0, marker: "1.", text: "first"),
          ]))
    #expect(blocks[3] == .quote("quoted"))
    #expect(blocks[4] == .code("code\n\nafter blank"))
    #expect(blocks[5] == .table([["A", "B"], ["1", "2"]]))
    #expect(blocks[6] == .rule)
  }
  @Test func canonDiffMarksOnlyChangedLines() {
    let diff = TextDiff.lines(old: "one\ntwo\nthree", new: "one\n2\nthree\nfour")
    #expect(
      diff == [
        .init(kind: .same, text: "one"), .init(kind: .removed, text: "two"),
        .init(kind: .added, text: "2"), .init(kind: .same, text: "three"),
        .init(kind: .added, text: "four"),
      ])
    #expect(TextDiff.lines(old: "same", new: "same").allSatisfy { $0.kind == .same })
  }
  @Test func graphLayoutIsDeterministicSeparatedAndFollowsOrientation() {
    let nodes = ["a", "b", "c", "d", "e", "f"]
    let edges = [("a", "b"), ("b", "c"), ("c", "d"), ("d", "e"), ("e", "f")]
    let wide = GraphLayout.positions(nodes: nodes, edges: edges)
    #expect(wide == GraphLayout.positions(nodes: nodes, edges: edges))
    for (i, a) in nodes.enumerated() {
      for b in nodes.dropFirst(i + 1) {
        #expect(hypot(wide[a]!.x - wide[b]!.x, wide[a]!.y - wide[b]!.y) > 80)
      }
    }
    func spread(_ layout: [String: CGPoint]) -> (x: Double, y: Double) {
      let xs = layout.values.map(\.x)
      let ys = layout.values.map(\.y)
      return (xs.max()! - xs.min()!, ys.max()! - ys.min()!)
    }
    #expect(spread(wide).x > spread(wide).y)
    let tall = GraphLayout.positions(nodes: nodes, edges: edges, landscape: false)
    #expect(spread(tall).y > spread(tall).x)
  }
  @Test func loreReferencesRoundTripBetweenTokensAndMarkdown() {
    let base: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15)]
    let markdown =
      "Ask [Mira Vale](synthesis://record/ABC-123) about [the sea](synthesis://record/x9), not [a web link](https://example.com)."
    let shown = MentionCodec.attributed(markdown, base: base, accent: .blue, soft: .gray)
    #expect(shown.string == "Ask Mira Vale about the sea, not [a web link](https://example.com).")
    #expect(shown.attribute(MentionCodec.key, at: 4, effectiveRange: nil) as? String == "ABC-123")
    #expect(shown.attribute(MentionCodec.key, at: 0, effectiveRange: nil) == nil)
    #expect(MentionCodec.markdown(shown) == markdown)
    #expect(MentionCodec.markdown(NSAttributedString(string: "plain")) == "plain")

    let text = "Tell me about @mir" as NSString
    #expect(MentionCodec.query(in: text, caret: text.length)?.text == "mir")
    #expect(
      MentionCodec.query(in: text, caret: text.length)?.range == NSRange(location: 14, length: 4))
    #expect(MentionCodec.query(in: "@" as NSString, caret: 1)?.text == "")
    #expect(MentionCodec.query(in: "mail@host" as NSString, caret: 9) == nil)
    #expect(MentionCodec.query(in: "@one\ntwo" as NSString, caret: 8) == nil)
    #expect(MentionCodec.query(in: "no mention" as NSString, caret: 10) == nil)
  }
  @Test func studioResolvesProposalsOnlyThroughExplicitActionsAndKeepsCanon() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    var rule = try store.createRecord(worldID: studio.worldID, title: "Rule", body: "One moon")
    rule = try store.promote(
      worldID: studio.worldID, id: rule.id, version: rule.version, confirmation: rule.id)
    let chat = try store.createConversation(worldID: studio.worldID)
    let message = try store.appendMessage(
      worldID: studio.worldID, conversationID: chat.id, role: "assistant", body: "Two ideas.",
      state: "complete")
    try store.stageProposal(
      worldID: studio.worldID, conversationID: chat.id, messageID: message.id,
      payload: [
        "summary": "Add a second moon",
        "changes": [
          ["action": "create_record", "kind": "entity", "title": "The Pale Moon"],
          ["action": "revise_record", "id": rule.id, "body": "Two moons"],
        ],
      ])
    // Review counts what waits on the creator even before the conversation is opened.
    try studio.reload()
    #expect(studio.pendingProposals.count == 1 && studio.reviewCount == 1)
    studio.openChat(chat)
    let proposal = try #require(studio.proposals[message.id])
    #expect(proposal.pending == 2 && studio.records.count == 1)
    #expect(studio.name(for: "change:\(proposal.changes[0].id)", in: proposal) == "The Pale Moon")

    studio.resolve(proposal, change: proposal.changes[1], accept: false)
    while studio.reviewingProposal { await Task.yield() }
    #expect(studio.proposals[message.id]?.pending == 1)
    #expect(try store.record(worldID: studio.worldID, id: rule.id).state == "canon")

    studio.resolveAll(try #require(studio.proposals[message.id]), accept: true)
    while studio.reviewingProposal { await Task.yield() }
    let resolved = try #require(studio.proposals[message.id])
    #expect(resolved.pending == 0 && resolved.state == "accepted")
    let moon = try #require(studio.records.first { $0.title == "The Pale Moon" })
    #expect(moon.origin == "ai-proposed" && moon.state == "draft")
    #expect(try store.record(worldID: studio.worldID, id: rule.id).body == "One moon")
    #expect(studio.toast?.message == "Saved reviewed changes. Canon is unchanged.")
    #expect(studio.pendingProposals.isEmpty && studio.reviewCount == 0)
    // Editing an accepted record puts it in the canon queue until it is reviewed.
    _ = try store.saveRecord(
      worldID: studio.worldID, id: rule.id, version: rule.version, title: "Rule",
      body: "Two moons", rtf: nil)
    try studio.reload()
    #expect(studio.canonQueue.map(\.id) == [rule.id] && studio.reviewCount == 1)
  }
  @Test func quickCaptureAndImportCreateLabelledDrafts() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.capture("  What if the tide runs backwards?\nAsk the keepers.  ")
    let idea = try #require(studio.records.first)
    #expect(idea.kind == "capture" && idea.state == "idea")
    #expect(
      idea.title == "What if the tide runs backwards?" && idea.body.contains("Ask the keepers."))
    studio.capture("   ")
    #expect(studio.records.count == 1)

    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let first = folder.appendingPathComponent("bell.md")
    let second = folder.appendingPathComponent("harbour.txt")
    let binary = folder.appendingPathComponent("image.md")
    try "# The Bell\n\nIt rings at low tide.".write(to: first, atomically: true, encoding: .utf8)
    try "Lanterns on the wall.".write(to: second, atomically: true, encoding: .utf8)
    try Data([0xFF, 0xFE, 0x00, 0xD8]).write(to: binary)
    studio.importDocuments([first, second, binary])
    let imported = studio.records.filter { $0.origin == "imported" }
    #expect(Set(imported.map(\.title)) == ["The Bell", "harbour"])
    #expect(imported.allSatisfy { $0.state == "draft" && $0.canonical == nil })
    #expect(studio.toast?.message.contains("Imported 2 documents") == true)
    #expect(studio.toast?.message.contains("1 skipped") == true)
    studio.toast?.action?()
    #expect(studio.records.filter { $0.origin == "imported" }.isEmpty)
    #expect(try store.archivedRecords(worldID: studio.worldID).count == 2)
  }
  @Test func boardContentReadsBothFormatsAndNeverGuessesAtDamagedData() throws {
    // A board saved by the earlier native canvas is recognised and kept verbatim.
    var old = CanvasDocument()
    old.cards = [CanvasCard(text: "Mira", recordID: "r1", x: -200, y: 40)]
    old.edges = [CanvasEdge(label: "knows", source: "a", target: "b")]
    let oldJSON = String(decoding: try JSONEncoder().encode(old), as: UTF8.self)
    let legacy = try CanvasBoardContent.decode(oldJSON)
    #expect(legacy.scene == nil && legacy.legacy?.cards.first?.recordID == "r1")
    #expect(legacy.legacyRaw == oldJSON)

    // After conversion the scene is stored in the new format with the original alongside.
    var converted = legacy
    converted.scene = [
      "elements": [
        ["id": "e1", "type": "rectangle", "customData": ["synthesis": "card", "recordID": "r1"]],
        ["id": "e2", "type": "text"],
      ],
      "appState": ["zoom": 1.0], "files": [String: Any](),
    ]
    converted.hiddenRelations = ["rel-1"]
    let stored = try converted.encoded()
    let reopened = try CanvasBoardContent.decode(stored)
    #expect(reopened.counts.cards == 1 && reopened.counts.elements == 2)
    #expect(reopened.hiddenRelations == ["rel-1"] && reopened.legacy == nil)
    let kept = try #require(reopened.legacyRaw)
    #expect(try JSONDecoder().decode(CanvasDocument.self, from: Data(kept.utf8)) == old)
    #expect(try CanvasBoardContent.decode(try reopened.encoded()).counts.cards == 1)

    // New empty boards and seed layouts both open; unreadable data is refused, not replaced.
    #expect(try CanvasBoardContent.decode(CanvasBoardContent.empty).counts.elements == 0)
    #expect(try CanvasBoardContent.decode("{}").legacy?.cards.isEmpty == true)
    #expect(throws: Error.self) { try CanvasBoardContent.decode("not-json") }
    #expect(throws: Error.self) { try CanvasBoardContent.decode("[1,2,3]") }
    #expect(throws: Error.self) { try CanvasBoardContent.decode(#"{"unexpected":true}"#) }
  }

}

@MainActor struct OnboardingTests {
  @Test func setupOnlyAppearsForANewInstallationAndExistingProviderChoiceSurvives() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let first = try Studio(store: store)
    #expect(first.sheet == .onboarding)
    #expect(first.provider == .codex)
    first.completeOnboarding()
    first.setProvider(.claudeCode)
    let reopened = try Studio(store: store)
    #expect(reopened.sheet == nil)
    #expect(reopened.provider == .claudeCode)
    let existing = try WorkspaceStore(path: ":memory:")
    _ = try existing.createWorld(name: "Existing work")
    #expect(try Studio(store: existing).sheet == nil)
  }
}
