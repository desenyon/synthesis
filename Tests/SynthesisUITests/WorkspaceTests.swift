import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct WorkspaceTests {
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
  @Test func delayedViewportSaveCannotOverwriteReopenedBoard() async throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let first = BoardController(studio: studio)
    first.load()
    first.moveViewport(CGSize(width: 12, height: 8))
    #expect(first.save())  // Navigation flush cancels the delayed save.
    let second = BoardController(studio: studio)
    second.load()
    second.mutate { $0.cards.append(CanvasCard(text: "Newer edit")) }
    try await Task.sleep(for: .milliseconds(500))
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.document.cards.first?.text == "Newer edit")
    #expect(reopened.viewport.x == 12 && reopened.viewport.y == 8)
  }
  @Test func boardUndoPreservesSourceRecordAndSavedLayout() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let record = try store.createRecord(
      worldID: studio.worldID, title: "Mira", body: "Cartographer", kind: "entity")
    let board = BoardController(studio: studio)
    board.load()
    board.add(record)
    board.mutate {
      $0.cards[0].x = 211
      $0.cards[0].group = "group-a"
    }
    board.viewport = BoardViewport(x: 3, y: 4, zoom: 0.9)
    #expect(board.save())
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.document.cards[0].x == 211 && reopened.document.cards[0].group == "group-a")
    #expect(reopened.viewport.zoom == 0.9)
    board.removeSelection()
    #expect(board.document.cards.isEmpty)
    board.step(back: true)
    #expect(board.document.cards.first?.recordID == record.id)
    #expect(try store.record(worldID: studio.worldID, id: record.id).body == "Cartographer")
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
  @Test func malformedBoardIsPreservedAndDoesNotTrapNavigation() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    _ = try store.saveBoard(
      worldID: studio.worldID, name: "Damaged", kind: "canvas", content: "not-json")
    let board = BoardController(studio: studio)
    board.load()
    #expect(!board.loaded && board.failure != nil)
    #expect(board.save())  // No pending edits exist; allow leaving without overwriting.
    #expect(try store.boards(worldID: studio.worldID, kind: "canvas").first?.content == "not-json")
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
  @Test func connectorsLeaveAndEnterOnFacingSides() {
    let left = CGRect(x: 0, y: 0, width: 300, height: 160)
    let right = CGRect(x: 500, y: 20, width: 300, height: 160)
    let across = EdgeGeometry.between(left, right)
    #expect(across.start.x > left.maxX && across.end.x < right.minX)
    #expect(across.heading == CGVector(dx: 1, dy: 0))
    let below = CGRect(x: 10, y: 400, width: 300, height: 160)
    let down = EdgeGeometry.between(left, below)
    #expect(down.start.y > left.maxY && down.end.y < below.minY)
    #expect(down.heading == CGVector(dx: 0, dy: 1))
    let lanes = edgeLanes([
      DisplayEdge(id: "a", source: "x", target: "y", label: "leads"),
      DisplayEdge(id: "b", source: "y", target: "x", label: "serves"),
      DisplayEdge(id: "c", source: "x", target: "z", label: "maps"),
    ])
    #expect(lanes["a"] != lanes["b"] && lanes["c"] == 0)
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
  @Test func boardZoomKeepsTheAnchoredPointAndLayoutToolsAreUndoable() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let board = BoardController(studio: studio)
    board.load()
    board.viewport = BoardViewport(x: 40, y: -20, zoom: 1)
    let anchor = CGPoint(x: 150, y: 90)
    let world = CGPoint(x: (anchor.x - 40) / 1, y: (anchor.y + 20) / 1)
    board.zoom(factor: 1.5, anchor: anchor)
    #expect(abs(world.x * board.viewport.zoom + board.viewport.x - anchor.x) < 0.001)
    #expect(abs(world.y * board.viewport.zoom + board.viewport.y - anchor.y) < 0.001)
    board.zoom(factor: 100, anchor: .zero)
    #expect(board.viewport.zoom == 2)
    for title in ["One", "Two", "Three"] {
      board.add(try store.createRecord(worldID: studio.worldID, title: title, kind: "entity"))
    }
    let positions = board.document.cards.map { CGPoint(x: $0.x, y: $0.y) }
    #expect(Set(positions.map { "\($0.x),\($0.y)" }).count == 3)
    board.selectAll()
    board.arrange(row: false, sizes: [:])
    #expect(Set(board.document.cards.map(\.x)).count == 1)
    board.group()
    #expect(board.selectionIsGrouped)
    board.ungroup()
    #expect(!board.selectionIsGrouped)
    board.step(back: true)
    board.step(back: true)
    board.step(back: true)
    #expect(board.document.cards.map { CGPoint(x: $0.x, y: $0.y) } == positions)
    board.rename("  The coast  ")
    let reopened = BoardController(studio: studio)
    reopened.load()
    #expect(reopened.name == "The coast" && reopened.document.cards.count == 3)
  }

}
