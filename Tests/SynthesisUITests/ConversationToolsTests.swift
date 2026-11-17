import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct ConversationToolsUITests {
  @Test func recipeAppendsPendingKeystrokesInManualAndNeverSends() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    studio.sheet = nil
    studio.setMode(.manual)
    studio.draft = "Earlier writing"
    studio.pendingComposer = (studio.worldID, "Latest unsent writing", studio.draft)
    let recipe = try studio.store.createPromptRecipe(
      worldID: studio.worldID,
      title: "Political tension", instructions: "Compare motivations with cited lore.",
      mode: "Critique")
    let options = studio.contextOptions
    try studio.usePromptRecipe(worldID: studio.worldID, recipeID: recipe.id)
    #expect(studio.draft == "Latest unsent writing\n\nCompare motivations with cited lore.")
    #expect(try studio.store.preference("composer:\(studio.worldID)") == studio.draft)
    #expect(studio.pendingComposer == nil && studio.preset == "Critique")
    #expect(studio.mode == .manual && studio.contextOptions == options)
    #expect(await transport.requests.isEmpty)
    let text = studio.draft
    let other = try studio.store.createWorld(name: "Other world")
    #expect(throws: Error.self) {
      try studio.usePromptRecipe(worldID: other.id, recipeID: recipe.id)
    }
    #expect(studio.draft == text)
    try studio.archivePromptRecipe(recipe, archived: true)
    #expect(throws: Error.self) {
      try studio.usePromptRecipe(worldID: studio.worldID, recipeID: recipe.id)
    }
    #expect(studio.draft == text)
    studio.toast?.action?()
    #expect(try studio.store.promptRecipes(worldID: studio.worldID).map(\.id) == [recipe.id])
  }

  @Test func branchingOpensTheNewThreadAndSourceRevealWithoutModelRequests() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    studio.sheet = nil
    let original = try studio.store.createConversation(
      worldID: studio.worldID, title: "Old account")
    let first = try studio.store.appendMessage(
      worldID: studio.worldID, conversationID: original.id,
      role: "user", body: "The first question", state: "complete")
    try studio.store.appendMessage(
      worldID: studio.worldID, conversationID: original.id,
      role: "assistant", body: "An authored scenario", state: "imported-example")
    try studio.reload()
    studio.openChat(original)
    studio.setMode(.manual)
    studio.draft = "Keep my next idea"
    studio.branchConversation(at: first.id)
    let branchID = try #require(studio.conversationID)
    #expect(branchID != original.id && studio.messages.count == 1)
    #expect(studio.draft == "Keep my next idea" && studio.mode == .manual)
    let branch = try #require(
      try studio.store.conversationBranch(worldID: studio.worldID, conversationID: branchID))
    studio.conversationScrollAnchors[original.id] = "stale-message"
    studio.openBranchSource(branch)
    #expect(studio.conversationID == original.id && studio.conversationReadTarget() == first.id)
    #expect(studio.conversationRevealMessageID == first.id)
    studio.conversationRevealMessageID = nil
    #expect(studio.conversationReadTarget() == nil)
    #expect(studio.conversationScrollAnchors[original.id] == nil)
    #expect(await transport.requests.isEmpty)
    studio.conversationScrollAnchors[original.id] = first.id
    #expect(studio.conversationReadTarget() == first.id)
  }

  @Test func recipeEditUndoCannotClobberANewerEdit() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: RecordingResponse())
    let recipe = try studio.store.createPromptRecipe(
      worldID: studio.worldID,
      title: "Motive", instructions: "First instruction", mode: "Develop")
    let edited = try studio.store.updatePromptRecipe(
      worldID: studio.worldID, id: recipe.id,
      version: recipe.version, title: recipe.title, instructions: "Edited instruction",
      mode: recipe.mode)
    studio.offerRecipeEditUndo(previous: recipe, saved: edited)
    let undo = studio.toast?.action
    let newest = try studio.store.updatePromptRecipe(
      worldID: studio.worldID, id: recipe.id,
      version: edited.version, title: recipe.title, instructions: "Newer instruction",
      mode: recipe.mode)
    undo?()
    #expect(try studio.store.promptRecipe(worldID: studio.worldID, id: recipe.id) == newest)
    #expect(studio.error != nil)
  }

  @Test func openRecipeActionsStayBoundToTheirOriginalUniverse() async throws {
    let transport = RecordingResponse()
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"), transport: transport)
    let firstWorld = studio.worldID
    let recipe = try studio.store.createPromptRecipe(
      worldID: firstWorld, title: "Private approach",
      instructions: "Explore this universe's private history.", mode: "Develop")
    let second = try studio.store.createWorld(name: "Unrelated universe")
    studio.switchWorld(second.id)
    studio.draft = "Second-world writing"
    #expect(throws: Error.self) {
      try studio.usePromptRecipe(worldID: firstWorld, recipeID: recipe.id)
    }
    #expect(throws: Error.self) { try studio.archivePromptRecipe(recipe, archived: true) }
    #expect(studio.draft == "Second-world writing")
    #expect(try studio.store.promptRecipes(worldID: second.id).isEmpty)
    #expect(try studio.store.promptRecipe(worldID: firstWorld, id: recipe.id) == recipe)
    #expect(await transport.requests.isEmpty)
  }
}
