import Foundation
import SynthesisCore

extension Studio {
  static let assistantCitationCaptureStates = ["assistant-citation", "assistant-citation-passage"]

  func configureAssistantCitationCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    perform {
      let title = "The Glass Sea harbour charter"
      let chat =
        try store.conversations(worldID: worldID).first { $0.title == title }
        ?? store.createConversation(worldID: worldID, title: title)
      if try store.messages(worldID: worldID, conversationID: chat.id).isEmpty {
        let record = try store.createRecord(
          worldID: worldID, title: "Harbour charter",
          body:
            "The harbour remained open through the winter.\n\nThe Tidekeepers held the port in Year 40. Their seal is recorded on the harbour charter.",
          category: "History"
        )
        let approval = try store.promote(
          worldID: worldID, id: record.id, version: record.version, confirmation: record.id)
        var options = AssistantContextOptions()
        options.scope = .attachments
        options.canonOnly = true
        options.recordIDs = [record.id]
        options.includeSelection = false
        let question = "Who held the port in Year 40?"
        let context = try store.assistantContext(
          worldID: worldID, prompt: question, options: options)
        try store.appendMessage(
          worldID: worldID, conversationID: chat.id, role: "user", body: question, state: "complete"
        )
        let reply = try store.appendMessage(
          worldID: worldID, conversationID: chat.id, role: "assistant",
          body: context.linkAcceptedCitations(
            in:
              "The Tidekeepers held the port in Year 40. [[cite:2]]\n\nTheir reasons are still open to interpretation."
          ),
          state: "imported-example")
        try store.saveMessageContext(
          worldID: worldID, messageID: reply.id, sources: context.sources)
        _ = try store.saveRecord(
          worldID: worldID, id: record.id, version: approval.version, title: "Revised charter",
          body: "Explore whether the port changed hands before the winter.", rtf: nil)
      }
      try reload()
      openChat(chat)
      captureHint = state
    }
  }
}
