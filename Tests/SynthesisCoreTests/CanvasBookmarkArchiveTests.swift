import Foundation
import Testing

@testable import SynthesisCore

struct CanvasBookmarkArchiveTests {
  @Test func canvasBookmarksRetainLiteralLabelsAndBoardScopeInPortableCopies() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let source = try store.createWorld(name: "Coast")
    let marker = try store.createRecord(worldID: source.id, title: "Watchtower", kind: "entity")
    let bookmarks: [[String: Any]] = [
      ["id": "viewpoint", "name": "Frame \(marker.id)", "x": -25.5, "y": 641, "zoom": 1.2]
    ]
    let scene: [String: Any] = [
      "elements": [["customData": ["synthesis": "card", "recordID": marker.id]]],
      "viewportBookmarks": bookmarks,
    ]
    let data = try JSONSerialization.data(withJSONObject: ["format": "excalidraw", "scene": scene])
    let framed = try store.saveBoard(
      worldID: source.id, name: "Coastal expedition", kind: "canvas",
      content: String(decoding: data, as: UTF8.self))
    _ = try store.saveBoard(worldID: source.id, name: "Side notes", kind: "canvas", content: "{}")

    let copiedWorld = try store.importWorldArchive(store.exportWorldArchive(worldID: source.id))
    let copiedMarker = try #require(store.records(worldID: copiedWorld.id).first)
    let copiedBoards = try store.boards(worldID: copiedWorld.id, kind: "canvas")
    let copied = try #require(copiedBoards.first { $0.name == framed.name })
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(copied.content.utf8)) as? [String: Any])
    let copiedScene = try #require(object["scene"] as? [String: Any])

    #expect(copied.id != framed.id)
    #expect(copiedMarker.id != marker.id)
    #expect(copied.content.contains(copiedMarker.id))
    let copiedBookmarks = try #require(copiedScene["viewportBookmarks"] as? [[String: Any]])
    #expect(NSArray(array: copiedBookmarks).isEqual(to: bookmarks))
    #expect(copiedBoards.first { $0.name == "Side notes" }?.content == "{}")
  }
}
