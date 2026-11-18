import AppKit
import Foundation
import SynthesisCore

extension Studio {
  static let recordBacklinkCaptureStates = ["record-backlinks", "light-record-backlinks"]

  func configureRecordBacklinkCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.recordBacklinkCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    perform {
      let title = "The tidal ledger"
      let target: LoreRecord
      if let existing = records.first(where: { $0.title == title }) {
        target = existing
      } else {
        target = try store.createRecord(
          worldID: worldID, title: title, body: "A register of crossings kept at the harbor.")
        let link = WorldReference(worldID: worldID, kind: .record, id: target.id).url
        let rich = NSAttributedString(string: title, attributes: [.link: link])
        let data = try rich.data(
          from: NSRange(location: 0, length: rich.length),
          documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let page = try store.createRecord(worldID: worldID, title: "Harbor plan")
        _ = try store.saveRecord(
          worldID: worldID, id: page.id, version: page.version, title: page.title,
          body: rich.string, rtf: data.base64EncodedString())
        _ = try store.createRecord(
          worldID: worldID, title: "A keeper's notes", body: "Check the tidal ledger at dusk.")
        try reload()
      }
      let backlinks = try store.recordBacklinks(worldID: worldID, recordID: target.id)
      guard backlinks.linked.map(\.title) == ["Harbor plan"],
        backlinks.mentioned.map(\.title) == ["A keeper's notes"]
      else { throw SynthesisError.invalid("The backlink fixture needs two distinct sources.") }
      openRecord(target)
      inspector = true
      dark = !state.hasPrefix("light-")
      captureHint = state
    }
  }
}
