import Foundation
import SynthesisCore

extension Studio {
  public static let conversationToolsCaptureStates = [
    "conversation-branch", "light-conversation-branch", "manual-conversation-branch",
    "conversation-branch-source", "conversation-branch-companion",
    "recipe-library", "light-recipe-library", "manual-recipe-library",
    "recipe-editor", "recipe-empty", "recipe-applied", "recipe-archived",
  ]

  /// Authored fixture discussions only. This path is inaccessible to the normal app and never
  /// calls a provider; the screenshot runner supplies an isolated store and no live transport.
  func configureConversationToolsCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil,
      Self.conversationToolsCaptureStates.contains(state)
    else { return }
    configureConnectedCapture("conversation", board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    inspector = false
    workspaceInspector = false
    companionExpanded = false
    captureHint = state
    perform {
      let sourceTitle = "The crossing — original account"
      let source =
        try store.conversations(worldID: worldID).first(where: { $0.title == sourceTitle })
        ?? store.createConversation(worldID: worldID, title: sourceTitle)
      if try store.messages(worldID: worldID, conversationID: source.id).isEmpty {
        try store.appendMessage(
          worldID: worldID, conversationID: source.id, role: "user",
          body:
            "What changes if Mira takes the northern route instead of following the Tidekeepers?",
          state: "complete")
        let reply = try store.appendMessage(
          worldID: worldID, conversationID: source.id, role: "assistant",
          body: """
            ### An alternative crossing

            The northern route keeps Mira closer to the Glass Sea. It gives her room to act independently, but removes the protection of the Tidekeepers.

            **A question to explore:** what does she notice before the others arrive?

            This is an authored hypothetical for the visual fixture, not established history or a model response.
            """, state: "imported-example")
        if let record = records.first(where: { $0.title == "Mira Vale" }) {
          try store.saveMessageContext(
            worldID: worldID, messageID: reply.id,
            sources: [ContextSource(record: record, reason: "Selected character")])
        }
        try store.appendMessage(
          worldID: worldID, conversationID: source.id, role: "user",
          body: "Keep the Tidekeepers' route in this original account.", state: "complete")
      }
      let sourceMessages = try store.messages(worldID: worldID, conversationID: source.id)
      guard let fork = sourceMessages.first(where: { $0.role == "assistant" }) else {
        throw SynthesisError.invalid("The branch fixture has no source response.")
      }
      let childTitle = "Mira's northern crossing"
      let child =
        try store.conversations(worldID: worldID).first(where: { $0.title == childTitle })
        ?? store.branchConversation(
          worldID: worldID, conversationID: source.id, at: fork.id, title: childTitle)
      try reload()
      openChat(child)
      if state.hasSuffix("source") {
        guard let lineage = try store.conversationBranch(worldID: worldID, conversationID: child.id)
        else {
          throw SynthesisError.invalid("The branch fixture has no lineage.")
        }
        openBranchSource(lineage)
      }
      if state.hasSuffix("companion") {
        navigate(.canvas)
        companionExpanded = true
        companionWidth = 430
      }
      if state.contains("recipe-") {
        newChat()
        draft = ""
        persistComposer()
        // A deterministic fixture library, distinct from the user's own world and provider.
        let allRecipes =
          try store.promptRecipes(worldID: worldID)
          + store.promptRecipes(worldID: worldID, archived: true)
        for recipe in allRecipes where !recipe.archived {
          try store.setPromptRecipeArchived(
            worldID: worldID, id: recipe.id, version: recipe.version, archived: true)
        }
        if !state.hasSuffix("empty") {
          let samples = [
            (
              "Character motives", "Develop",
              "Explore the character's motives, private fears and loyalties. Cite the selected lore and keep alternatives hypothetical."
            ),
            (
              "Read between the histories", "Critique",
              "Compare accounts of this event. Separate documented facts, conflicting claims and what remains unknown."
            ),
            (
              "A political turning point", "Simulate",
              "Explore how these organizations might react to the proposed event. State assumptions and identify which world rules constrain them."
            ),
          ]
          for sample in samples {
            if let existing = allRecipes.first(where: { $0.title == sample.0 }) {
              let current = try store.promptRecipe(worldID: worldID, id: existing.id)
              try store.setPromptRecipeArchived(
                worldID: worldID, id: current.id, version: current.version, archived: false)
            } else {
              _ = try store.createPromptRecipe(
                worldID: worldID, title: sample.0, instructions: sample.2, mode: sample.1)
            }
          }
        }
        if state.hasSuffix("archived"), let recipe = try store.promptRecipes(worldID: worldID).first
        {
          try store.setPromptRecipeArchived(
            worldID: worldID, id: recipe.id, version: recipe.version, archived: true)
        }
        if state.hasSuffix("applied"), let recipe = try store.promptRecipes(worldID: worldID).first
        {
          draft = "Mira is deciding whether to leave the Tidekeepers."
          try usePromptRecipe(worldID: worldID, recipeID: recipe.id)
          toast = nil
        }
      } else {
        draft = "Explore what Mira discovers on the northern shore. Keep this branch hypothetical."
        persistComposer()
      }
      captureHint = state
      let copied = try store.messages(worldID: worldID, conversationID: child.id)
      guard copied.count == 2, copied.last?.body == fork.body,
        try store.conversationBranch(worldID: worldID, conversationID: child.id)?.forkMessageID
          == fork.id,
        try store.messages(worldID: worldID, conversationID: source.id).count == 3
      else {
        throw SynthesisError.invalid(
          "Conversation capture did not preserve the source prefix and lineage.")
      }
      guard !busy else {
        throw SynthesisError.invalid("A conversation fixture unexpectedly started a model request.")
      }
      print(
        "CONVERSATION_TOOLS_AUDIT PASS \(state): persisted branch/recipe data, source lineage and no active model request"
      )
    }
  }
}
