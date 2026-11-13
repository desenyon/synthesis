import AppKit
import Foundation
import SynthesisCore

// Authored sample data for the isolated screenshot runner only. Never used as a provider.
extension Studio {
  public func prepareConnectedCapture() throws -> (board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else {
      throw SynthesisError.invalid("Capture fixtures require the isolated runner.")
    }
    loadSample()
    let sea = try store.createRecord(
      worldID: worldID, title: "The Glass Sea",
      body:
        "At dawn, the water becomes a dark mirror. The drowned city remains visible beneath it until the first tide returns.",
      kind: "entity", category: "Places")
    let power = try store.createRecord(
      worldID: worldID, title: "The art of remembrance",
      body:
        "Borrow a memory. Live the skill inside it.\n\nCost: one memory of your own.\nRestriction: a borrowed life cannot be changed.",
      kind: "entity", category: "Power systems")
    try reload()
    let mira = records.first { $0.title == "Mira Vale" }!
    let order = records.first { $0.title == "Tidekeepers" }!
    _ = try store.addRelation(worldID: worldID, source: mira.id, target: sea.id, label: "maps")
    _ = try store.addRelation(
      worldID: worldID, source: order.id, target: power.id, label: "safeguards")
    var document = CanvasDocument()
    document.viewport = BoardViewport()
    let positions = [(-210.0, -155.0), (210.0, -155.0), (-210.0, 155.0), (210.0, 155.0)]
    let imageURL = Bundle.main.resourceURL?.appendingPathComponent("Assets/aster-coast.png")
    let image = imageURL.flatMap { try? Data(contentsOf: $0) }
    for (index, record) in [mira, order, sea, power].enumerated() {
      var card = CanvasCard(text: record.title, recordID: record.id)
      card.width = 300
      card.x = positions[index].0
      card.y = positions[index].1
      if record.id == sea.id { card.image = image?.base64EncodedString() }
      document.cards.append(card)
    }
    if let image { worldCover = NSImage(data: image) }
    let board = try store.saveBoard(
      worldID: worldID, name: "The first crossing", kind: "canvas",
      content: String(decoding: try JSONEncoder().encode(document), as: UTF8.self))
    let chat = try store.createConversation(
      worldID: worldID, title: "The price of remembrance · sample")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "user",
      body:
        "How might [Mira Vale](synthesis://record/\(mira.id)) cross the sea without losing the memory of her sister?",
      state: "complete")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "assistant",
      body:
        "## A choice worth exploring\n\nThe [art of remembrance](synthesis://record/\(power.id)) asks for a memory in return. Mira could borrow a Tidekeeper’s crossing skill—but choose to surrender the memory of her first map instead.\n\n| Possibility | Consequence |\n| --- | --- |\n| Borrow the skill | Lose her first map |\n| Cross without it | Trust an uncertain route |\n\nThis is a hypothetical direction. The existing drafts do not establish which memory the sea would accept.",
      state: "imported-example")
    try store.appendMessage(
      worldID: worldID, conversationID: chat.id, role: "user",
      body:
        "Keep both possibilities open. I want the [Tidekeepers](synthesis://record/\(order.id)) to disagree about what the crossing costs.",
      state: "complete")
    try reload()
    return (board.id, chat.id)
  }
  public func configureConnectedCapture(_ state: String, board: String, conversation: String) {
    _ = flushEditor()
    editorSave = nil
    selectedRecord = nil
    stop()
    setMode(state == "manual" ? .manual : .assisted)
    dark = state != "light"
    collapsed = state == "collapsed"
    canvasBoardID = board
    companionExpanded = state == "companion"
    companionWidth = 400
    draft = ""
    conversationID = state == "conversation-home" ? nil : conversation
    perform { try reload() }
    switch state {
    case "conversation-home", "conversation": destination = .chat
    case "library": destination = .library
    case "graph": destination = .knowledge
    default: destination = .canvas
    }
  }
}
