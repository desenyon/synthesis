import Foundation
import Testing

@testable import SynthesisCore

@MainActor struct WorkspaceActionTests {
  @Test func boardActionsAreWorldScopedReviewedAndKeepExistingScene() throws {
    let s = try WorkspaceStore(path: ":memory:")
    let world = try s.createWorld(name: "A")
    let other = try s.createWorld(name: "B")
    let entity = try s.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let foreign = try s.saveBoard(worldID: other.id, name: "Foreign", kind: "canvas", content: "{}")
    let proposal = try #require(
      try s.stageProposal(
        worldID: world.id, conversationID: nil, messageID: nil,
        payload: [
          "changes": [
            ["action": "create_board", "title": "Crossing"],
            [
              "action": "place_record", "board": "Crossing", "source": entity.id, "x": 120, "y": 80,
            ],
            ["action": "place_record", "board": foreign.id, "source": entity.id],
            ["action": "place_record", "board": "Crossing", "source": entity.id, "x": 999_999_999],
          ]
        ]))
    #expect(proposal.changes.count == 2)
    #expect(try s.boards(worldID: world.id, kind: "canvas").isEmpty)
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[1].id, accept: true,
        confirmation: proposal.id)
    }
    #expect(throws: Error.self) {
      try s.resolveChange(
        worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
        confirmation: "")
    }
    var reviewed = try s.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[0].id, accept: true,
      confirmation: proposal.id)
    let boardID = try #require(reviewed.changes[0].resultID)
    _ = try s.saveBoard(
      worldID: world.id, id: boardID, name: "Crossing", kind: "canvas",
      content:
        #"{"format":"excalidraw","scene":{"elements":[{"id":"drawing","type":"ellipse","x":0,"y":0}],"files":{"existing":{"id":"existing"}}},"hiddenRelations":["hidden"]}"#
    )
    reviewed = try s.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[1].id, accept: true,
      confirmation: proposal.id)
    let board = try #require(try s.boards(worldID: world.id, kind: "canvas").first)
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(board.content.utf8)) as? [String: Any])
    let scene = try #require(object["scene"] as? [String: Any])
    let elements = try #require(scene["elements"] as? [[String: Any]])
    #expect(elements.count == 2 && elements[0]["id"] as? String == "drawing")
    #expect((elements[1]["customData"] as? [String: String])?["recordID"] == entity.id)
    #expect(elements[1]["x"] as? Double == 120)
    #expect((scene["files"] as? [String: Any])?["existing"] != nil)
    #expect(object["hiddenRelations"] as? [String] == ["hidden"])
    #expect(try s.record(worldID: world.id, id: entity.id).state == "draft")
    _ = try s.resolveChange(
      worldID: world.id, proposalID: proposal.id, changeID: proposal.changes[1].id, accept: true,
      confirmation: proposal.id)
    #expect(try s.boards(worldID: world.id, kind: "canvas").first?.content == board.content)
  }
  @Test func agentReceivesRealRelationshipsChronologyAndBoardMembership() async throws {
    let s = try WorkspaceStore(path: ":memory:")
    let world = try s.createWorld(name: "A")
    let other = try s.createWorld(name: "B")
    let a = try s.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let b = try s.createRecord(worldID: world.id, title: "Keepers", kind: "entity")
    _ = try s.addRelation(worldID: world.id, source: a.id, target: b.id, label: "trained by")
    _ = try s.addEvent(
      worldID: world.id, title: "First Crossing", date: "Year of Rain", source: a.id)
    _ = try s.saveBoard(worldID: world.id, name: "Expedition", kind: "canvas", content: "{}")
    _ = try s.saveBoard(worldID: other.id, name: "PRIVATE FOREIGN", kind: "canvas", content: "{}")
    let c = try s.createConversation(worldID: world.id)
    let transport = CountingTransport()
    try await AgentEngine(store: s, transport: transport).submit(
      worldID: world.id, conversationID: c.id, prompt: "Help arrange Mira and her Keepers",
      preset: "Develop"
    ) { _ in }
    let context = await transport.lastRequest?.instructions ?? ""
    #expect(
      context.contains("trained by") && context.contains("First Crossing")
        && context.contains("Expedition"))
    #expect(!context.contains("PRIVATE FOREIGN"))
    #expect(context.contains("place_record"))
  }
  @Test func movingAGroupedCardPreservesOtherCardsAndIndexesEachRecordOnce() throws {
    let s = try WorkspaceStore(path: ":memory:")
    let world = try s.createWorld(name: "A")
    let a = try s.createRecord(worldID: world.id, title: "A", kind: "entity")
    let b = try s.createRecord(worldID: world.id, title: "B", kind: "entity")
    let parts: [[String: Any]] = [
      [
        "id": "a", "x": 10, "y": 20, "groupIds": ["a", "outer"],
        "customData": ["synthesis": "card", "recordID": a.id],
      ],
      [
        "id": "a-title", "x": 20, "y": 30, "groupIds": ["a", "outer"],
        "customData": ["synthesis": "text", "recordID": a.id],
      ],
      [
        "id": "b", "x": 500, "y": 20, "groupIds": ["b", "outer"],
        "customData": ["synthesis": "card", "recordID": b.id],
      ],
    ]
    let content: [String: Any] = [
      "format": "excalidraw",
      "scene": ["elements": parts, "files": ["image": ["dataURL": "preserve"]]],
      "hiddenRelations": ["hidden"],
    ]
    let board = try s.saveBoard(
      worldID: world.id, name: "Board", kind: "canvas",
      content: String(decoding: JSONSerialization.data(withJSONObject: content), as: UTF8.self))
    let moved = try s.placeRecord(
      worldID: world.id, boardID: board.id, recordID: a.id, x: 100, y: 200)
    let data = try #require(
      try JSONSerialization.jsonObject(with: Data(moved.content.utf8)) as? [String: Any])
    let scene = try #require(data["scene"] as? [String: Any])
    let elements = try #require(scene["elements"] as? [[String: Any]])
    #expect(elements.count == 3)
    #expect(elements[0]["x"] as? Int == 100 && elements[1]["x"] as? Int == 110)
    #expect(elements[2]["x"] as? Int == 500)
    #expect((scene["files"] as? [String: Any])?["image"] != nil)
    let context = try #require(
      try JSONSerialization.jsonObject(with: Data(s.workspaceContext(worldID: world.id).utf8))
        as? [String: Any])
    let boards = try #require(context["boards"] as? [[String: Any]])
    #expect(boards.first?["totalPlacements"] as? Int == 2)
  }
  @Test func mapPlacementPreservesImageAndRejectsForeignRecords() throws {
    let s = try WorkspaceStore(path: ":memory:")
    let world = try s.createWorld(name: "A")
    let other = try s.createWorld(name: "Other")
    let record = try s.createRecord(worldID: world.id, title: "Harbour", kind: "entity")
    let foreign = try s.createRecord(worldID: other.id, title: "Elsewhere", kind: "entity")
    let board = try s.saveBoard(
      worldID: world.id, name: "Sea", kind: "atlas",
      content: #"{"image":"unchanged","markers":[],"custom":"preserve"}"#)
    #expect(throws: Error.self) {
      try s.placeMapMarker(
        worldID: world.id, boardID: board.id, recordID: foreign.id, x: 0.5, y: 0.5)
    }
    #expect(throws: Error.self) {
      try s.placeMapMarker(worldID: world.id, boardID: board.id, recordID: record.id, x: 2, y: 0)
    }
    _ = try s.placeMapMarker(
      worldID: world.id, boardID: board.id, recordID: record.id, x: 0.2, y: 0.3)
    let moved = try s.placeMapMarker(
      worldID: world.id, boardID: board.id, recordID: record.id, x: 0.8, y: 0.7)
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(moved.content.utf8)) as? [String: Any])
    let markers = try #require(object["markers"] as? [[String: Any]])
    #expect(markers.count == 1 && markers[0]["x"] as? Double == 0.8)
    #expect(object["image"] as? String == "unchanged" && object["custom"] as? String == "preserve")
  }
  @Test func ambiguousTitlesNeverChooseAnArbitraryRecord() throws {
    let s = try WorkspaceStore(path: ":memory:")
    let world = try s.createWorld(name: "A")
    _ = try s.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    _ = try s.createRecord(worldID: world.id, title: "Mira", kind: "entity")
    let target = try s.createRecord(worldID: world.id, title: "Sea", kind: "entity")
    let proposal = try s.stageProposal(
      worldID: world.id, conversationID: nil, messageID: nil,
      payload: [
        "changes": [["action": "relate", "source": "Mira", "target": target.id, "label": "maps"]]
      ])
    #expect(proposal == nil)
  }
}
