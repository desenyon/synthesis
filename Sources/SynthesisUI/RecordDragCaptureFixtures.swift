import Foundation
import SynthesisCore

extension Studio {
  func configureRecordDragCapture(_ state: String, board: String, conversation: String) {
    endRecordDrag()
    let base = state.contains("canvas") ? "canvas" : "atlas-linked"
    configureConnectedCapture(base, board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    guard let record = records.first(where: { $0.title == "Mira Vale" }) else { return }
    setFavorite(record, enabled: true)
    captureHint = state
    if state.hasSuffix("search") {
      paletteQuery = "Mira"
      palette = true
    } else if state.hasSuffix("opened") {
      _ = beginRecordDrag(record, monitor: false)
      let id = recordDrag!.id
      let location = navigationLocation
      Task { @MainActor in
        do {
          let data = try JSONEncoder().encode(
            RecordDragAddress(worldID: record.worldID, recordID: record.id))
          guard await receiveRecordDrop(data, target: .beside, location: location, dragID: id)
          else {
            throw SynthesisError.invalid("Capture record drop failed.")
          }
        } catch { self.error = error.localizedDescription }
      }
    } else if state.hasSuffix("second-pane") {
      if let sea = records.first(where: { $0.title == "The Glass Sea" }) { openBeside(sea) }
      _ = beginRecordDrag(record, monitor: false)
    } else if !state.hasSuffix("favorites") {
      _ = beginRecordDrag(record, monitor: false)
    }
  }
}
