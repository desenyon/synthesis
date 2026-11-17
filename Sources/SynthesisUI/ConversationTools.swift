import SwiftUI
import SynthesisCore

extension Studio {
  /// Resolve only messages in the displayed conversation. Explicit lineage jumps win over
  /// remembered positions, and a stale address cannot reveal another conversation or world.
  func conversationReadTarget() -> String? {
    guard let id = conversationID else { return nil }
    let valid = Set(messages.filter { $0.worldID == worldID && $0.conversationID == id }.map(\.id))
    if let reveal = conversationRevealMessageID {
      if valid.contains(reveal) { return reveal }
      conversationRevealMessageID = nil
    }
    if let anchor = conversationScrollAnchors[id] {
      if valid.contains(anchor) { return anchor }
      conversationScrollAnchors[id] = nil
    }
    return nil
  }

  func branchConversation(at messageID: String, keepWorkspace: Bool = false) {
    guard !busy, let sourceID = conversationID,
      messages.contains(where: { $0.id == messageID && ["user", "assistant"].contains($0.role) })
    else { return }
    withNavigation {
      guard flushEditor() else { return }
      persistPendingComposer()
      perform {
        let branch = try store.branchConversation(
          worldID: worldID, conversationID: sourceID, at: messageID)
        try reload()
        openChat(branch, keepWorkspace: keepWorkspace)
        show(
          "Opened a new branch. The original conversation is unchanged.",
          icon: "arrow.triangle.branch")
      }
    }
  }

  func openBranchSource(_ branch: ConversationBranch, keepWorkspace: Bool = false) {
    guard branch.worldID == worldID, !busy else { return }
    perform {
      // Restoring is explicit in the archived-parent button label. Never hide the source.
      if branch.parentArchived {
        try store.setConversationArchived(
          worldID: worldID, id: branch.parentConversationID, archived: false)
        try reload()
      }
      guard let original = conversations.first(where: { $0.id == branch.parentConversationID })
      else {
        throw SynthesisError.notFound
      }
      openChat(original, keepWorkspace: keepWorkspace)
      if conversationID == original.id { conversationRevealMessageID = branch.forkMessageID }
    }
  }

  /// Only prepares a draft. Provider/mode permissions, lore scope and approval policy stay intact.
  /// Pending local keystrokes are included before insertion, even inside the debounce window.
  func usePromptRecipe(worldID expectedWorld: String, recipeID: String) throws {
    guard worldID == expectedWorld else { throw SynthesisError.notFound }
    let recipe = try store.promptRecipe(worldID: expectedWorld, id: recipeID)
    guard !recipe.archived else {
      throw SynthesisError.invalid("Restore this recipe before using it.")
    }
    let current =
      pendingComposer.flatMap {
        $0.world == worldID && $0.base == draft ? $0.text : nil
      } ?? draft
    let next = current.isEmpty ? recipe.instructions : current + "\n\n" + recipe.instructions
    guard next.count <= 300_000 else {
      throw SynthesisError.invalid(
        "This recipe would make the message too long. Shorten the current draft first.")
    }
    // Commit first; an I/O failure must preserve both the pending text and current mode.
    try store.setPreference("composer:\(expectedWorld)", value: next)
    pendingComposer = nil
    draft = next
    preset = recipe.mode
    show("Added “\(recipe.title)” to your draft")
  }

  func archivePromptRecipe(_ recipe: PromptRecipe, archived: Bool) throws {
    guard recipe.worldID == worldID else { throw SynthesisError.notFound }
    let result = try store.setPromptRecipeArchived(
      worldID: worldID, id: recipe.id,
      version: recipe.version, archived: archived)
    worldRevision += 1
    show(
      "\(archived ? "Archived" : "Restored") “\(recipe.title)”", icon: "archivebox",
      actionTitle: "Undo"
    ) { [weak self] in
      guard let self, self.worldID == recipe.worldID else { return }
      self.perform {
        try self.store.setPromptRecipeArchived(
          worldID: recipe.worldID, id: recipe.id,
          version: result.version, archived: recipe.archived)
        self.worldRevision += 1
      }
    }
  }

  func offerRecipeEditUndo(previous: PromptRecipe, saved: PromptRecipe) {
    show("Saved “\(saved.title)”", actionTitle: "Undo") { [weak self] in
      guard let self, self.worldID == previous.worldID else { return }
      self.perform {
        try self.store.updatePromptRecipe(
          worldID: previous.worldID, id: previous.id,
          version: saved.version, title: previous.title, instructions: previous.instructions,
          mode: previous.mode)
        self.worldRevision += 1
      }
    }
  }
}

struct ConversationLineage: View {
  @ObservedObject var studio: Studio
  let branch: ConversationBranch
  var companion = false
  private var excerpt: String {
    let plain =
      (try? AttributedString(markdown: branch.forkExcerpt)).map { String($0.characters) }
      ?? branch.forkExcerpt
    return plain.replacingOccurrences(of: "\n", with: " ")
  }
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      StudioIcon("arrow.triangle.branch", size: 15).foregroundStyle(studio.t.secondary)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 5) {
        Text("Branched from \(branch.parentTitle)").font(.studio(.label)).lineLimit(1)
        Text(excerpt)
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(2)
        Button(
          branch.parentArchived
            ? "Restore original & open fork point" : "Open original at fork point"
        ) {
          studio.openBranchSource(branch, keepWorkspace: companion)
        }.buttonStyle(.plain).font(.studio(.captionStrong)).foregroundStyle(studio.t.accent)
          .disabled(studio.busy)
      }
      Spacer(minLength: 0)
    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
      .background(studio.t.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: Metric.radius))
      .accessibilityElement(children: .contain).accessibilityLabel("Conversation branch lineage")
  }
}

/// A single manager is used by every composer and by the Conversation toolbar in Manual mode.
struct PromptRecipesSheet: View {
  @ObservedObject var studio: Studio
  let worldID: String
  var initialInstructions = ""
  var createOnOpen = false
  var close: () -> Void
  @State private var recipes: [PromptRecipe] = []
  @State private var archivedRecipes: [PromptRecipe] = []
  @State private var query = ""
  @State private var showArchived = false
  @State private var editing = false
  @State private var original: PromptRecipe?
  @State private var title = ""
  @State private var instructions = ""
  @State private var mode = "Develop"
  @State private var initialTitle = ""
  @State private var initialBody = ""
  @State private var initialMode = "Develop"
  @State private var failure: String?
  @State private var discardConfirmation = false
  @State private var closeAfterDiscard = false
  private var dirty: Bool {
    editing && (title != initialTitle || instructions != initialBody || mode != initialMode)
  }
  private var visible: [PromptRecipe] {
    let values = showArchived ? archivedRecipes : recipes
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return needle.isEmpty
      ? values
      : values.filter {
        $0.title.localizedStandardContains(needle)
          || $0.instructions.localizedStandardContains(needle)
          || $0.mode.localizedStandardContains(needle)
      }
  }
  var body: some View {
    SheetScaffold(
      title: editing
        ? (original == nil ? "New prompt recipe" : "Edit prompt recipe") : "Prompt recipes",
      subtitle:
        "Reusable instructions for this universe. Using a recipe prepares a draft for you to edit and send.",
      t: studio.t, width: 600, close: { requestClose() }
    ) {
      if let failure {
        Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.warning)
          .fixedSize(horizontal: false, vertical: true).accessibilityLabel(
            "Recipe error: \(failure)")
      }
      if editing { editor } else { browser }
    } footer: {
      if editing {
        Button("Back") { abandonEditor() }.buttonStyle(QuietButton(t: studio.t))
        Spacer()
        Button("Save recipe", action: save).buttonStyle(QuietButton(t: studio.t, primary: true))
          .keyboardShortcut("s", modifiers: .command)
          .disabled(
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      } else {
        Button(showArchived ? "Active recipes" : "Archived recipes") {
          showArchived.toggle()
          failure = nil
        }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
        Spacer()
        Button("New recipe") { beginEditing(nil) }.buttonStyle(
          QuietButton(t: studio.t, primary: true))
      }
    }.interactiveDismissDisabled(dirty)
      .onAppear {
        reload()
        showArchived = studio.captureHint.hasSuffix("recipe-archived")
        if createOnOpen { beginEditing(nil, seed: initialInstructions) }
      }
      .onChange(of: studio.worldRevision) { _, _ in reload() }
      .onChange(of: studio.worldID) { _, value in
        if value != worldID {
          failure =
            "The active universe changed. Return to this recipe's universe before saving or using it. Your edits are kept here."
        } else {
          reload()
        }
      }
      .alert("Discard recipe edits?", isPresented: $discardConfirmation) {
        Button("Keep editing", role: .cancel) {}
        Button("Discard edits", role: .destructive) {
          if closeAfterDiscard {
            close()
          } else {
            editing = false
            failure = nil
          }
        }
      } message: {
        Text("The saved recipe is unchanged. Your unsaved edits will be discarded.")
      }
  }

  private var editor: some View {
    VStack(alignment: .leading, spacing: 14) {
      FormField(
        label: "Name", placeholder: "Character motivations, political tensions…", text: $title,
        t: studio.t, autofocus: true)
      HStack {
        Text("Assistant mode").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
        Spacer()
        PlainMenu {
          ForEach(Vocabulary.modes, id: \.name) { choice in
            Button(choice.name) { mode = choice.name }
          }
        } label: {
          HStack(spacing: 7) {
            Text(mode)
            StudioIcon("chevron.down", size: 9)
          }.font(.studio(.label)).padding(.horizontal, 10).frame(height: 32)
            .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        }.accessibilityLabel("Recipe assistant mode: \(mode)")
      }
      FormTextArea(
        label: "Instructions",
        placeholder: "Describe the questions, constraints and format you want to reuse.",
        text: $instructions, t: studio.t, height: 220)
      Text(
        "Recipes do not change lore access, Manual mode, or canon approval. Add references and context when you use the recipe."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary).fixedSize(
        horizontal: false, vertical: true)
    }
  }

  private var browser: some View {
    VStack(alignment: .leading, spacing: 12) {
      FormField(placeholder: "Search recipes", text: $query, t: studio.t)
        .accessibilityLabel("Search prompt recipes")
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if visible.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text(
                query.isEmpty
                  ? (showArchived ? "No archived recipes" : "Keep your useful prompts close.")
                  : "No matching recipes"
              )
              .font(.studio(size: 17, weight: .semibold))
              Text(
                query.isEmpty
                  ? "Save a repeatable approach to developing characters, exploring history or critiquing a story. Your world supplies the context when you use it."
                  : "Try a different title, instruction or assistant mode."
              )
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 28).padding(.horizontal, 4)
          }
          ForEach(visible) { recipe in row(recipe) }
        }
      }.frame(minHeight: 220, maxHeight: 340)
    }
  }

  private func row(_ recipe: PromptRecipe) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(recipe.title).font(.studio(size: 14, weight: .semibold)).lineLimit(2)
        Spacer(minLength: 8)
        Text(recipe.mode).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      }
      Text(recipe.instructions).font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
        .lineSpacing(3).lineLimit(3)
      HStack(spacing: 6) {
        if recipe.archived {
          Button("Restore") {
            attempt {
              try studio.archivePromptRecipe(recipe, archived: false)
              reload()
            }
          }
          .buttonStyle(QuietButton(t: studio.t))
        } else {
          Button("Add to draft") {
            attempt {
              try studio.usePromptRecipe(worldID: worldID, recipeID: recipe.id)
              close()
            }
          }.buttonStyle(QuietButton(t: studio.t, primary: true))
          Button("Edit") { beginEditing(recipe) }.buttonStyle(
            QuietButton(t: studio.t, role: .ghost))
          Spacer()
          IconButton(icon: "archivebox", label: "Archive \(recipe.title)", t: studio.t) {
            attempt {
              try studio.archivePromptRecipe(recipe, archived: true)
              reload()
            }
          }
        }
      }
    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
  }

  private func beginEditing(_ recipe: PromptRecipe?, seed: String = "") {
    original = recipe
    title = recipe?.title ?? ""
    instructions = recipe?.instructions ?? seed
    mode = recipe?.mode ?? studio.preset
    initialTitle = title
    initialBody = instructions
    initialMode = mode
    editing = true
    failure = nil
  }
  private func requestClose() {
    if dirty {
      closeAfterDiscard = true
      discardConfirmation = true
    } else {
      close()
    }
  }
  private func abandonEditor() {
    if dirty {
      closeAfterDiscard = false
      discardConfirmation = true
    } else {
      editing = false
      failure = nil
    }
  }
  private func reload() {
    guard studio.worldID == worldID else { return }
    attempt {
      recipes = try studio.store.promptRecipes(worldID: worldID)
      archivedRecipes = try studio.store.promptRecipes(worldID: worldID, archived: true)
    }
  }
  private func save() {
    attempt {
      guard studio.worldID == worldID else { throw SynthesisError.notFound }
      if let original {
        let saved = try studio.store.updatePromptRecipe(
          worldID: worldID, id: original.id,
          version: original.version, title: title, instructions: instructions, mode: mode)
        studio.offerRecipeEditUndo(previous: original, saved: saved)
      } else {
        _ = try studio.store.createPromptRecipe(
          worldID: worldID, title: title, instructions: instructions, mode: mode)
        studio.show("Saved “\(title.trimmingCharacters(in: .whitespacesAndNewlines))”")
      }
      studio.worldRevision += 1
      editing = false
      showArchived = false
      query = ""
      reload()
    }
  }
  private func attempt(_ action: () throws -> Void) {
    do {
      try action()
      failure = nil
    } catch { failure = error.localizedDescription }
  }
}
