import AppKit
import SynthesisCore

extension Studio {
  func configureWorldReferenceCapture(_ state: String, board: String, conversation: String) {
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    perform {
      guard let event = try store.events(worldID: worldID).first else {
        throw SynthesisError.notFound
      }
      let address = WorldReference(worldID: worldID, kind: .event, id: event.id)
      let source = try store.resolveReference(address, worldID: worldID)
      captureHint = state
      if state == "reference-composer" {
        guard appendWorkspaceReference(address) else {
          throw SynthesisError.invalid("The composer did not accept the capture reference.")
        }
        return
      }
      let title = "Crossing notes"
      let record =
        try records.first { $0.title == title }
        ?? store.createRecord(worldID: worldID, title: title)
      let beginning = "Check the account of "
      let text = beginning + source.title + " before drawing the next leg of the crossing."
      let rich = NSMutableAttributedString(
        string: text,
        attributes: [.font: StudioTypography.native(size: CGFloat(preferences.bodySize))])
      rich.addAttribute(
        .link, value: source.reference.url,
        range: NSRange(location: beginning.utf16.count, length: source.title.utf16.count))
      let encoded = try rich.data(
        from: NSRange(location: 0, length: rich.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
      ).base64EncodedString()
      let saved = try store.saveRecord(
        worldID: worldID, id: record.id, version: record.version, title: record.title,
        body: text, rtf: encoded)
      try reload()
      openRecord(saved)
    }
  }
}
