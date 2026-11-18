import AppKit
import SwiftUI
import SynthesisCore

/// Message composer shared by Conversation, the companion and the compact canvas bar. Keystrokes
/// stay local; the draft is persisted on a short debounce and flushed on disappear.
struct UnifiedComposer: View {
  @ObservedObject var studio: Studio
  var companion = false
  var collapsed = false
  @State private var focused = false
  @State private var text = ""
  @State private var loadedWorld = ""
  @State private var syncedDraft = ""
  @State private var saveTask: Task<Void, Never>?
  @State private var inputHeight: CGFloat = 26
  @State private var referencesHeight: CGFloat = 28
  @State private var referencePicker = false
  @State private var contextPicker = false
  @State private var inspectingContext = false
  @State private var expanded = false
  @State private var recipesPresented = false
  @State private var recipesWorldID = ""
  @State private var saveRecipe = false
  @State private var recipeSeed = ""
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var mentionQuery: String?
  @State private var mentionIndex = 0
  @State private var handle = ComposerHandle()
  private var empty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  /// Records offered while an `@name` is being typed: title prefixes first, then other matches.
  private var mentionMatches: [LoreRecord] {
    guard let query = mentionQuery else { return [] }
    if query.isEmpty { return Array(studio.records.prefix(6)) }
    let hit = studio.records.filter {
      $0.title.localizedCaseInsensitiveContains(query)
        || ($0.aliases ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
    }
    let leading = hit.filter { $0.title.lowercased().hasPrefix(query.lowercased()) }
    return Array((leading + hit.filter { r in !leading.contains { $0.id == r.id } }).prefix(6))
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Group {
        if collapsed { compactField } else { fullField }
      }
      .background {
        FrostedSurface(
          t: studio.t, radius: collapsed ? ComposerMetric.compactRadius : ComposerMetric.radius)
      }
      .overlay(
        RoundedRectangle(
          cornerRadius: collapsed ? ComposerMetric.compactRadius : ComposerMetric.radius
        ).stroke(
          focused ? studio.t.accent.opacity(0.35) : studio.t.border, lineWidth: 1)
      )
      .elevation(collapsed ? .compactComposer : .composer, t: studio.t)
      .overlay(alignment: .topLeading) {
        if !mentionMatches.isEmpty {
          // Sits just above the field so it never covers what is being typed.
          mentionList.fixedSize()
            .offset(x: 8, y: -(CGFloat(mentionMatches.count) * 35 + 44))
        }
      }
      disclosure
    }
    .animation(reduceMotion ? nil : .easeOut(duration: ComposerMetric.transition), value: focused)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: expanded)
    .workspaceReferenceDrop(
      studio: studio,
      receive: { source in
        guard loadedWorld == source.reference.worldID else { return false }
        saveTask?.cancel()
        commitDraft()
        return studio.appendWorkspaceReference(source.reference)
      }
    )
    .popover(isPresented: $contextPicker) {
      AssistantContextPanel(
        studio: studio, prompt: text, attachments: true,
        nextMessageOnly: !studio.activeRequestPins.isEmpty)
    }
    .popover(isPresented: $inspectingContext) {
      AssistantContextPanel(studio: studio, prompt: text)
    }
    .popover(isPresented: $referencePicker) {
      SearchableRecordPicker(records: studio.records, t: studio.t) { record in
        handle.insertReference(title: record.title, id: record.id)
        referencePicker = false
      }
    }
    .studioSheet(isPresented: $recipesPresented) {
      PromptRecipesSheet(
        studio: studio, worldID: recipesWorldID,
        initialInstructions: recipeSeed, createOnOpen: saveRecipe,
        close: { recipesPresented = false })
    }
    .onAppear {
      loadedWorld = studio.worldID
      text = studio.draft
      syncedDraft = studio.draft
      expanded = studio.captureHint == "composer-expanded"
    }
    .onChange(of: studio.draft) { _, value in
      syncedDraft = value
      if value != text { text = value }
    }
    .onChange(of: text) { _, _ in
      if loadedWorld == studio.worldID, studio.draft == syncedDraft {
        studio.pendingComposer = (loadedWorld, text, syncedDraft)
      }
      saveTask?.cancel()
      saveTask = Task { @MainActor in
        do {
          try await Task.sleep(for: .milliseconds(500))
          commitDraft()
        } catch {}
      }
    }
    .onDisappear {
      saveTask?.cancel()
      commitDraft()
    }
  }
  private var fullField: some View {
    let attachments = studio.composerAttachments
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text("World assistant").font(.studio(.label))
          .foregroundStyle(studio.t.secondary)
        if attachments.count > 3 {
          Text("\(attachments.count) references")
            .font(.studio(size: 11)).foregroundStyle(studio.t.muted)
        }
        Spacer(minLength: 0)
        IconButton(
          icon: expanded ? "minus" : "arrow.up.left.and.arrow.down.right",
          label: expanded ? "Compact composer" : "Expand composer", t: studio.t,
          size: ComposerMetric.control
        ) { expanded.toggle() }
      }
      ComposerInput(
        text: $text,
        placeholder: "What should happen in \(studio.world?.name ?? "your world")?",
        color: studio.t.text, placeholderColor: studio.t.secondary, accent: studio.t.accent,
        accentSoft: studio.t.accentSoft, autofocus: !companion,
        sendShortcut: studio.preferences.sendShortcut, handle: handle,
        onFocus: { focused = $0 }, onHeight: { inputHeight = $0 }, onMention: updateMention,
        onMentionKey: mentionKey, submit: send
      ).frame(height: expanded ? 220 : min(160, max(56, inputHeight)))
        // NSTextView has its own 5pt line-fragment inset. Align typed text to the heading.
        .padding(.horizontal, -5)
      if !attachments.isEmpty || !selectedReferences.isEmpty {
        GeometryReader { viewport in
          ScrollView {
            FlowLayout(spacing: 6) {
              ForEach(attachments) { item in attachmentChip(item) }
              ForEach(selectedReferences) { record in
                HStack(spacing: 6) {
                  StudioIcon(categoryIcon(record.category), size: 12)
                  Text(record.title).font(.studio(.caption)).lineLimit(1).frame(maxWidth: 150)
                  Text("Selected").font(.studio(size: 11)).foregroundStyle(studio.t.muted)
                }.padding(.horizontal, 8).frame(height: 28)
                  .foregroundStyle(studio.t.secondary).background(
                    studio.t.secondarySurface.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: Metric.radius)
                  )
                  .help("Included from the current selection. Change this in World context.")
              }
            }.frame(width: viewport.size.width, alignment: .leading)
              .onGeometryChange(for: CGFloat.self) { area in
                area.size.height
              } action: { height in
                referencesHeight = height
              }
          }.scrollBounceBehavior(.basedOnSize)
        }.frame(height: min(62, max(28, referencesHeight)))
      }
      ViewThatFits(in: .horizontal) {
        controls(contextLabel: true)
        controls(contextLabel: false)
        controls(contextLabel: false, modeLabel: false)
      }
    }.padding(ComposerMetric.inset)
  }
  private func controls(contextLabel: Bool, modeLabel: Bool = true) -> some View {
    HStack(spacing: 4) {
      attachment
      modeMenu(labels: modeLabel)
      intentMenu
      Spacer(minLength: 8)
      contextControl(labels: contextLabel)
      sendButton
    }
  }
  private var compactField: some View {
    let pins = studio.composerAttachments.filter(\.pinned)
    return VStack(alignment: .leading, spacing: Space.sm) {
      HStack(alignment: .bottom, spacing: 4) {
        attachment
        ComposerInput(
          text: $text,
          placeholder: "Ask about \(studio.contextLabel)…", color: studio.t.text,
          placeholderColor: studio.t.muted, accent: studio.t.accent,
          accentSoft: studio.t.accentSoft, sendShortcut: studio.preferences.sendShortcut,
          handle: handle, onFocus: { focused = $0 }, onHeight: { inputHeight = $0 },
          onMention: updateMention, onMentionKey: mentionKey, submit: send
        ).frame(height: min(96, max(ComposerMetric.control, inputHeight)))
        contextControl(labels: false)
        IconButton(
          icon: "sidebar.right", label: "Open the companion conversation", t: studio.t,
          size: ComposerMetric.control
        ) {
          commitDraft()
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            studio.companionExpanded = true
          }
        }
        sendButton
      }
      if !pins.isEmpty {
        ScrollView(.horizontal) {
          HStack(spacing: 6) {
            ForEach(pins) { item in attachmentChip(item) }
          }
        }.scrollBounceBehavior(.basedOnSize).frame(height: 28)
      }
    }.padding(12)
  }
  private var selectedReferences: [LoreRecord] {
    guard studio.contextOptions.includeSelection else { return [] }
    let pins = Set(studio.activeRequestPins.recordIDs)
    return studio.records.filter {
      studio.contextualRecordIDs.contains($0.id) && !studio.contextOptions.recordIDs.contains($0.id)
        && !studio.contextOptions.excludedRecordIDs.contains($0.id) && !pins.contains($0.id)
    }
  }
  private func attachmentChip(_ item: ComposerAttachment) -> some View {
    let remove = item.pinned ? "Remove pin for \(item.title)" : "Remove attachment \(item.title)"
    return HStack(spacing: 6) {
      StudioIcon(item.pinned ? "pin" : item.icon, size: 12)
        .foregroundStyle(item.pinned ? studio.t.accent : studio.t.secondary)
      Text(item.title).font(.studio(size: 12.5)).lineLimit(1).frame(maxWidth: 170)
      Button {
        studio.removeAttachment(item)
      } label: {
        StudioIcon("xmark", size: 9).frame(width: 22, height: 24)
          .hoverFill(studio.t, radius: 5)
      }.buttonStyle(.plain).help(remove).accessibilityLabel(remove)
    }.padding(.leading, 8).padding(.trailing, 2).frame(height: 28)
      .foregroundStyle(studio.t.secondary)
      .background(
        item.pinned ? studio.t.accentSoft : studio.t.secondarySurface,
        in: RoundedRectangle(cornerRadius: Metric.radius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Metric.radius).stroke(
          item.pinned ? studio.t.accent.opacity(0.3) : studio.t.hairline, lineWidth: 0.5
        )
        .allowsHitTesting(false)
      ).help(item.pinned ? "\(item.title) · Next message only" : item.title)
  }
  private var intentMenu: some View {
    PlainMenu {
      ForEach(AssistantIntent.allCases, id: \.self) { intent in
        Button {
          studio.updateContext { $0.intent = intent }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(intent.title).font(.studio(.label))
              Spacer()
              if studio.contextOptions.intent == intent { StudioIcon("checkmark", size: 12) }
            }
            Text(
              intent == .explore
                ? "Discuss possibilities. No changes are staged."
                : "Prepare draft changes for you to review."
            )
            .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          }
        }
      }
    } label: {
      HStack(spacing: 5) {
        Text(studio.contextOptions.intent == .explore ? "Explore" : "Propose")
        StudioIcon("chevron.down", size: 8)
      }.font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.secondary)
        .padding(.horizontal, 8).frame(height: ComposerMetric.control)
        .hoverFill(studio.t, radius: Metric.radius)
    }.help("Whether to explore ideas or stage changes for review")
      .accessibilityLabel("Assistant intent: \(studio.contextOptions.intent.title)")
  }
  private func canonNotice(labels: Bool) -> some View {
    PlainMenu {
      Text("Canon protected").font(.studio(size: 13, weight: .semibold)).padding(8)
      Text(
        "Proposals are suggestions. Accepting one saves a draft; promoting that draft to canon requires a separate, explicit review."
      )
      .font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary).padding(8)
      Button("Open Review") {
        commitDraft()
        studio.navigate(.review)
      }
    } label: {
      HStack(spacing: 5) {
        StudioIcon("lock.shield", size: 12)
        if labels { Text("Canon protected").font(.studio(size: 11)) }
      }.foregroundStyle(studio.t.muted).padding(.horizontal, 4).frame(height: 24)
        .hoverFill(studio.t, radius: 6)
    }.help("How Synthesis protects canon").accessibilityLabel("How Synthesis protects canon")
  }
  private func contextControl(labels: Bool) -> some View {
    Button {
      commitDraft()
      inspectingContext = true
    } label: {
      HStack(spacing: 5) {
        StudioIcon("square.stack", size: 13)
        if labels {
          Text(studio.contextOptions.scope.title).font(.studio(size: 12.5))
        } else if !studio.composerAttachments.isEmpty {
          Text("\(studio.composerAttachments.count)").font(.studio(size: 11.5)).monospacedDigit()
        }
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, labels ? 8 : 0)
        .frame(minWidth: ComposerMetric.control, minHeight: ComposerMetric.control)
        .hoverFill(studio.t, radius: Metric.radius)
    }.buttonStyle(.plain).help("Inspect and control the context shared with your assistant")
      .accessibilityLabel("Inspect world context")
  }
  private var disclosure: some View {
    ViewThatFits(in: .horizontal) {
      disclosureRow(detailed: true)
      disclosureRow(detailed: false)
    }.font(.studio(size: 11)).foregroundStyle(studio.t.muted)
      .padding(.horizontal, 4)
  }
  private func disclosureRow(detailed: Bool) -> some View {
    HStack(spacing: 8) {
      if !collapsed { canonNotice(labels: detailed) }
      Group {
        if studio.providerConfigured {
          Text(detailed ? "Context is shared with your AI provider" : "Context shared on Send")
            .help(studio.providerDisclosure)
        } else {
          Button {
            commitDraft()
            studio.openAssistantSettings()
          } label: {
            HStack(spacing: 5) {
              StudioIcon("bolt.slash", size: 11)
              Text("Connect \(studio.provider.title)")
            }.foregroundStyle(studio.t.secondary).frame(height: 24)
              .hoverFill(studio.t, radius: 6)
          }.buttonStyle(.plain)
            .help("Connect your subscription in Settings. Messages stay local until you send.")
        }
      }
      Spacer(minLength: 4)
      if detailed {
        Text(
          studio.preferences.sendShortcut == .enter
            ? "↵ Send · ⇧↵ New line" : "⌘↵ Send · ↵ New line"
        )
        .help("Change the send shortcut in Settings → Writing.")
      }
    }.lineLimit(1).fixedSize(horizontal: false, vertical: true)
  }
  private var attachment: some View {
    PlainMenu {
      Button("Attach lore, map, Canvas or history…") {
        commitDraft()
        contextPicker = true
      }
      Button("Insert an inline @ reference…") { referencePicker = true }
      Button("Attach a text or Markdown file…") {
        commitDraft()
        studio.attachText()
        text = studio.draft
      }
      Divider()
      Button("Prompt recipes…") { openRecipes() }
      Button("Save draft as recipe…") { openRecipes(saveDraft: true) }.disabled(empty)
      Divider()
      Button("Assistant settings…") {
        commitDraft()
        studio.openAssistantSettings()
      }
    } label: {
      StudioIcon("plus", size: 16).foregroundStyle(studio.t.secondary)
        .frame(width: ComposerMetric.control, height: ComposerMetric.control)
        .hoverFill(studio.t, radius: Metric.radius)
    }.help("Attach world context or a file").accessibilityLabel("Add context or file")
  }
  private var mentionList: some View {
    VStack(alignment: .leading, spacing: 1) {
      ForEach(Array(mentionMatches.enumerated()), id: \.element.id) { offset, record in
        Button {
          mentionIndex = offset
          commitMention()
        } label: {
          HStack(spacing: 9) {
            CategoryTile(record: record, t: studio.t, size: 24)
            Text(record.title).font(.studio(size: 13.5, weight: .medium)).lineLimit(1)
            Spacer(minLength: 12)
            Text(
              record.category.isEmpty
                ? Vocabulary.kindLabel(record.kind) : Vocabulary.displayCategory(record.category)
            )
            .font(.studio(.caption)).foregroundStyle(studio.t.muted).lineLimit(1)
          }.padding(.horizontal, 8).frame(height: 34)
            .background(
              offset == mentionIndex ? studio.t.secondarySurface : .clear,
              in: RoundedRectangle(cornerRadius: Metric.smallRadius)
            )
            .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { if $0 { mentionIndex = offset } }
      }
      HStack(spacing: 10) {
        Text("↑↓ choose").font(.studio(size: 11))
        Text("↵ insert").font(.studio(size: 11))
        Text("esc close").font(.studio(size: 11))
      }.foregroundStyle(studio.t.muted).padding(.horizontal, 8).padding(.top, 5).padding(.bottom, 2)
    }.padding(6).frame(width: 320).floatingPanel(studio.t)
      .accessibilityElement(children: .contain).accessibilityLabel("Lore suggestions")
  }
  private func updateMention(_ query: String?) {
    if query != mentionQuery { mentionIndex = 0 }
    mentionQuery = query
  }
  private func commitMention() {
    let matches = mentionMatches
    guard matches.indices.contains(mentionIndex) else { return }
    let record = matches[mentionIndex]
    mentionQuery = nil
    handle.insertReference(title: record.title, id: record.id, replacingQuery: true)
  }
  private func mentionKey(_ key: ComposerTextView.MentionKey) -> Bool {
    let count = mentionMatches.count
    guard count > 0 else { return false }
    switch key {
    case .up: mentionIndex = (mentionIndex - 1 + count) % count
    case .down: mentionIndex = (mentionIndex + 1) % count
    case .commit: commitMention()
    case .cancel: mentionQuery = nil
    }
    return true
  }
  private func modeMenu(labels: Bool) -> some View {
    PlainMenu {
      ForEach(Vocabulary.modes, id: \.name) { mode in
        Button {
          studio.preset = mode.name
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              StudioIcon(mode.icon, size: 14)
              Text(mode.name).font(.studio(size: 13.5, weight: .medium))
              Spacer()
              if studio.preset == mode.name { StudioIcon("checkmark", size: 12) }
            }
            Text(mode.summary).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }.padding(.vertical, 3)
        }
      }
      Divider()
      Button("Prompt recipes…") { openRecipes() }
      Button("Save draft as recipe…") { openRecipes(saveDraft: true) }.disabled(empty)
      Divider()
      MenuSection("Guided prompts") {
        ForEach(Vocabulary.categories + ["History", "Story threads"], id: \.self) { topic in
          Button(topic) {
            text =
              "Help me explore \(topic.lowercased()). Ask one question at a time, follow my direction, and keep all ideas hypothetical until I accept them."
          }
        }
      }
    } label: {
      HStack(spacing: 5) {
        if labels {
          Text(studio.preset).font(.studio(size: 12.5, weight: .medium))
        } else {
          StudioIcon(
            Vocabulary.modes.first { $0.name == studio.preset }?.icon ?? "sparkles", size: 14)
        }
        StudioIcon("chevron.down", size: 8)
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, 8)
        .frame(height: ComposerMetric.control).hoverFill(studio.t, radius: Metric.radius)
    }.help("Assistant mode: \(studio.preset)").accessibilityLabel(
      "Assistant mode: \(studio.preset)")
  }
  private var sendButton: some View {
    Button {
      if studio.busy { studio.stop() } else { send() }
    } label: {
      StudioIcon(studio.busy ? "stop.fill" : "arrow.up", size: 14)
    }.buttonStyle(ComposerSendStyle(t: studio.t))
      .disabled((empty && !studio.busy) || studio.mode == .manual)
      .help(
        studio.busy
          ? "Stop generating" : "Send (\(studio.preferences.sendShortcut == .enter ? "↵" : "⌘↵"))"
      )
      .accessibilityLabel(studio.busy ? "Stop generation" : "Send message")
  }
  private func commitDraft() {
    if studio.commitComposer(text: text, worldID: loadedWorld, replacing: syncedDraft) {
      syncedDraft = text
    }
  }
  private func openRecipes(saveDraft: Bool = false) {
    saveTask?.cancel()
    commitDraft()
    recipeSeed = saveDraft ? text : ""
    recipesWorldID = studio.worldID
    saveRecipe = saveDraft
    recipesPresented = true
  }
  private func send() {
    guard studio.mode == .assisted, !studio.busy else { return }
    saveTask?.cancel()
    commitDraft()
    studio.send(keepWorkspace: companion || collapsed)
    text = studio.draft
    if collapsed {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
        studio.companionExpanded = true
      }
    }
  }
}
