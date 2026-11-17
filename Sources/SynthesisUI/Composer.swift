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
  @State private var referencePicker = false
  @State private var contextPicker = false
  @State private var inspectingContext = false
  @State private var expanded = false
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
    VStack(alignment: .leading, spacing: 7) {
      Group {
        if collapsed { compactField } else { fullField }
      }
      .background(
        studio.t.surface,
        in: RoundedRectangle(
          cornerRadius: collapsed ? ComposerMetric.compactRadius : ComposerMetric.radius)
      )
      .overlay(
        RoundedRectangle(
          cornerRadius: collapsed ? ComposerMetric.compactRadius : ComposerMetric.radius
        ).stroke(
          focused ? studio.t.accent.opacity(0.5) : studio.t.border.opacity(0.9), lineWidth: 1)
      )
      .shadow(color: studio.t.shadow.opacity(collapsed ? 0.6 : 0.3), radius: 22, y: 8)
      .overlay(alignment: .topLeading) {
        if !mentionMatches.isEmpty {
          // Sits just above the field so it never covers what is being typed.
          mentionList.fixedSize()
            .offset(x: 8, y: -(CGFloat(mentionMatches.count) * 35 + 44))
        }
      }
      disclosure
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: inputHeight)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: expanded)
    .popover(isPresented: $contextPicker) {
      AssistantContextPanel(studio: studio, prompt: text, attachments: true)
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
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        StudioIcon("sparkles", size: 16).foregroundStyle(studio.t.secondary)
        Text("World assistant").font(.studio(size: 14, weight: .semibold))
        if studio.composerAttachments.count > 3 {
          Text("\(studio.composerAttachments.count) attached")
            .font(.studio(size: 11)).foregroundStyle(studio.t.secondary)
        }
        Spacer(minLength: 0)
        modeMenu
        IconButton(
          icon: expanded ? "minus" : "arrow.up.left.and.arrow.down.right",
          label: expanded ? "Compact composer" : "Expand composer", t: studio.t
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
      ).frame(height: expanded ? 220 : min(150, max(54, inputHeight)))
        .padding(.horizontal, 4).padding(.top, 2)
      if !studio.composerAttachments.isEmpty || !selectedReferences.isEmpty {
        ScrollView {
          FlowLayout(spacing: 6) {
            ForEach(studio.composerAttachments) { item in attachmentChip(item) }
            ForEach(selectedReferences) { record in
              HStack(spacing: 5) {
                StudioIcon(categoryIcon(record.category), size: 12)
                Text(record.title).font(.studio(size: 12)).lineLimit(1).frame(maxWidth: 150)
                Text("selected").font(.studio(size: 10)).foregroundStyle(studio.t.muted)
              }.padding(.horizontal, 9).frame(height: 27)
                .foregroundStyle(studio.t.secondary).background(
                  studio.t.secondarySurface.opacity(0.6), in: Capsule()
                )
                .help("Included from the current selection. Change this in World context.")
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.scrollBounceBehavior(.basedOnSize).frame(
          maxHeight: studio.composerAttachments.count + selectedReferences.count > 3 ? 68 : 29)
      }
      ViewThatFits(in: .horizontal) {
        controls(labels: true)
        controls(labels: false)
      }
    }.padding(ComposerMetric.inset)
  }
  private func controls(labels: Bool) -> some View {
    HStack(spacing: 5) {
      attachment
      intentMenu
      canonNotice(labels: labels)
      contextControl(labels: labels)
      Spacer(minLength: 2)
      sendButton
    }
  }
  private var compactField: some View {
    HStack(alignment: .bottom, spacing: 4) {
      attachment.padding(.bottom, 1)
      ComposerInput(
        text: $text,
        placeholder: "Ask about \(studio.contextLabel)…", color: studio.t.text,
        placeholderColor: studio.t.muted, accent: studio.t.accent,
        accentSoft: studio.t.accentSoft, sendShortcut: studio.preferences.sendShortcut,
        handle: handle, onFocus: { focused = $0 }, onHeight: { inputHeight = $0 },
        onMention: updateMention, onMentionKey: mentionKey, submit: send
      ).frame(height: min(96, max(26, inputHeight))).padding(.bottom, 2)
      contextControl(labels: false)
      IconButton(icon: "sidebar.right", label: "Open the companion conversation", t: studio.t) {
        commitDraft()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
          studio.companionExpanded = true
        }
      }.padding(.bottom, 1)
      sendButton
    }.padding(.leading, 11).padding(.trailing, 10).padding(.vertical, 12)
  }
  private var selectedReferences: [LoreRecord] {
    guard studio.contextOptions.includeSelection else { return [] }
    return studio.records.filter {
      studio.contextualRecordIDs.contains($0.id) && !studio.contextOptions.recordIDs.contains($0.id)
        && !studio.contextOptions.excludedRecordIDs.contains($0.id)
    }
  }
  private func attachmentChip(_ item: ComposerAttachment) -> some View {
    HStack(spacing: 5) {
      StudioIcon(item.icon, size: 12)
      Text(item.title).font(.studio(size: 12.5, weight: .medium)).lineLimit(1).frame(maxWidth: 170)
      Button {
        studio.removeAttachment(item)
      } label: {
        StudioIcon("xmark", size: 9).frame(width: 20, height: 24).contentShape(Rectangle())
      }.buttonStyle(.plain).help("Remove \(item.title)").accessibilityLabel(
        "Remove attachment \(item.title)")
    }.padding(.leading, 10).padding(.trailing, 3).frame(height: 28)
      .foregroundStyle(studio.t.secondary).background(studio.t.secondarySurface, in: Capsule())
  }
  private var intentMenu: some View {
    PlainMenu {
      ForEach(AssistantIntent.allCases, id: \.self) { intent in
        Button {
          studio.updateContext { $0.intent = intent }
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(intent.title).font(.studio(size: 13, weight: .medium))
              Spacer()
              if studio.contextOptions.intent == intent { StudioIcon("checkmark", size: 12) }
            }
            Text(
              intent == .explore
                ? "Discuss possibilities. No changes are staged."
                : "Prepare draft changes for you to review."
            )
            .font(.studio(size: 12)).foregroundStyle(studio.t.secondary)
          }
        }
      }
    } label: {
      HStack(spacing: 5) {
        Text(studio.contextOptions.intent == .explore ? "Explore" : "Propose")
        StudioIcon("chevron.down", size: 8)
      }.font(.studio(size: 12.5, weight: .medium)).padding(.horizontal, 10).frame(height: 28)
        .background(studio.t.secondarySurface, in: Capsule()).hoverFill(studio.t, radius: 14)
    }.help("Whether to explore ideas or stage changes for review")
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
        if labels { Text("Canon protected").font(.studio(size: 12)) }
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, 9).frame(height: 28)
        .hoverFill(studio.t, radius: 14)
    }.help("How Synthesis protects canon")
  }
  private func contextControl(labels: Bool) -> some View {
    Button {
      commitDraft()
      inspectingContext = true
    } label: {
      HStack(spacing: 5) {
        StudioIcon("square.stack", size: 13)
        if labels {
          Text(studio.contextOptions.scope.title).font(.studio(size: 12))
        } else if !studio.composerAttachments.isEmpty {
          Text("\(studio.composerAttachments.count)").font(.studio(size: 11.5)).monospacedDigit()
        }
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, 9).frame(height: 28)
        .background(studio.t.secondarySurface.opacity(labels ? 0.65 : 0), in: Capsule())
        .hoverFill(studio.t, radius: 14)
    }.buttonStyle(.plain).help("Inspect and control the context shared with your assistant")
      .accessibilityLabel("Inspect world context")
  }
  @ViewBuilder private var disclosure: some View {
    HStack(spacing: 5) {
      if studio.providerConfigured {
        Text("Shares world context with your AI provider").help(studio.providerDisclosure)
      } else {
        StudioIcon("bolt.slash", size: 10)
        Text(
          "Connect your \(studio.provider.title) subscription.")
        Button("Set up") { studio.openAssistantSettings() }.buttonStyle(.plain)
          .foregroundStyle(studio.t.accent)
        if !collapsed && !companion { Text("Messages are kept locally until then.") }
      }
    }.font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(1)
      .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
      .padding(.horizontal, 6)
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
      Button("Assistant settings…") {
        commitDraft()
        studio.openAssistantSettings()
      }
    } label: {
      StudioIcon("plus", size: 16).foregroundStyle(studio.t.secondary)
        .frame(width: 28, height: 28).hoverFill(studio.t, radius: 14)
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
            .font(.studio(size: 12)).foregroundStyle(studio.t.muted).lineLimit(1)
          }.padding(.horizontal, 8).frame(height: 34)
            .background(
              offset == mentionIndex ? studio.t.secondarySurface : .clear,
              in: RoundedRectangle(cornerRadius: 7)
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
  private var modeMenu: some View {
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
            Text(mode.summary).font(.studio(size: 12)).foregroundStyle(studio.t.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }.padding(.vertical, 3)
        }
      }
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
        StudioIcon(Vocabulary.modes.first { $0.name == studio.preset }?.icon ?? "sparkles")
          .font(.studio(size: 12))
        Text(studio.preset).font(.studio(size: 13, weight: .medium))
        StudioIcon("chevron.down", size: 8)
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, 7).frame(height: 28)
        .hoverFill(studio.t)
    }.help("Assistant mode: \(studio.preset)")
  }
  private var sendButton: some View {
    Button {
      if studio.busy { studio.stop() } else { send() }
    } label: {
      StudioIcon(studio.busy ? "stop.fill" : "arrow.up")
        .font(.studio(size: 13, weight: .semibold)).frame(width: 34, height: 34)
        .foregroundStyle(empty && !studio.busy ? studio.t.muted : studio.t.onAccent)
        .background(
          empty && !studio.busy ? studio.t.secondarySurface : studio.t.accent,
          in: RoundedRectangle(cornerRadius: 11))
    }.buttonStyle(.plain).disabled((empty && !studio.busy) || studio.mode == .manual)
      .help(studio.busy ? "Stop generating" : "Send")
      .accessibilityLabel(studio.busy ? "Stop generation" : "Send message")
  }
  private func commitDraft() {
    if studio.commitComposer(text: text, worldID: loadedWorld, replacing: syncedDraft) {
      syncedDraft = text
    }
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
