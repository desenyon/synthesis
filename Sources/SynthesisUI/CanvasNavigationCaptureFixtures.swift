import Foundation
import SynthesisCore
import WebKit

extension Studio {
  public static func isCanvasNavigationCapture(_ state: String) -> Bool {
    state == "canvas-navigation" || state == "manual-canvas-navigation"
  }

  func configureCanvasNavigationCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("canvas", board: board, conversation: conversation)
    perform {
      let boards = try store.boards(worldID: worldID, kind: "canvas")
      let name = "Coastal expedition"
      if let existing = boards.first(where: { $0.name == name }) {
        canvasBoardID = existing.id
      } else if let source = boards.first(where: { $0.id == board }) {
        let copy = try store.saveBoard(
          worldID: worldID, name: name, kind: "canvas", content: source.content)
        canvasBoardID = copy.id
        try reload()
      } else {
        throw SynthesisError.notFound
      }
      if state.hasPrefix("manual") { setMode(.manual) }
      captureHint = state
    }
  }

  public func openCanvasNavigationForCapture() async throws {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.isCanvasNavigationCapture(captureHint),
      let boardID = canvasBoardID, let session = canvasSession, session.boardID == boardID,
      session.loaded
    else { throw SynthesisError.invalid("Canvas navigation capture was not ready.") }

    let result = try await session.webView.callAsyncJavaScript(
      "return await window.synthesis.captureNavigation()", arguments: [:], in: nil,
      contentWorld: .page)
    guard result as? Bool == true, await session.flush(), session.failure == nil,
      let board = try store.boards(worldID: worldID, kind: "canvas").first(where: {
        $0.id == boardID
      }),
      let bookmarks = try CanvasBoardContent.decode(board.content).scene?["viewportBookmarks"]
        as? [[String: Any]], bookmarks.count == 2
    else {
      throw SynthesisError.invalid("Canvas navigation capture did not render its saved bookmarks.")
    }
  }
}
