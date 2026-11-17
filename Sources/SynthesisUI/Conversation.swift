import AppKit
import SwiftUI
import SynthesisCore

/// Conversation workspace. Used full width, or as the docked companion beside a canvas; both
/// read and write the same persisted conversation.
struct ConversationStudio: View {
  @ObservedObject var studio: Studio
  var companion = false
  /// False when the companion replaces the canvas in a narrow window.
  var docked = true
  @State private var followLatest = true
  var body: some View {
    GeometryReader { geo in
      let narrow = geo.size.width < 620
      VStack(spacing: 0) {
        bar
        if studio.messages.isEmpty && !studio.busy {
          ScrollView {
            VStack(alignment: .leading, spacing: companion ? 24 : 30) {
              emptyState(narrow: narrow)
              if studio.mode == .assisted {
                UnifiedComposer(studio: studio, companion: companion)
                if !companion { references }
              } else {
                manualNotice
              }
            }.frame(maxWidth: 780)
              .padding(.horizontal, narrow ? 20 : 40).padding(.vertical, 40)
              .frame(maxWidth: .infinity, minHeight: max(0, geo.size.height - Metric.bar))
          }
        } else {
          transcript(narrow: narrow)
          if studio.mode == .assisted {
            UnifiedComposer(studio: studio, companion: companion).frame(maxWidth: 780)
              .padding(.horizontal, narrow ? 14 : 32).padding(.top, 6).padding(.bottom, 18)
          } else {
            manualNotice.frame(maxWidth: 780).padding(.horizontal, narrow ? 14 : 32)
              .padding(.bottom, 18)
          }
        }
      }.frame(width: geo.size.width, height: geo.size.height).clipped()
    }.background(studio.t.background)
  }

  // MARK: Bar

  private var bar: some View {
    WorkspaceBar(studio: studio, global: !companion, inset: !companion || !docked) {
      StudioIcon("bubble.left", size: 14).foregroundStyle(studio.t.accent)
        .accessibilityHidden(true)
      if let chat = studio.conversations.first(where: { $0.id == studio.conversationID }) {
        PlainMenu(flexible: true) {
          Button("Rename…") {
            studio.renameTarget = chat.id
            studio.sheet = .rename
          }
          Button("Archive conversation") { studio.archive(chat) }
        } label: {
          HStack(spacing: 5) {
            Text(chat.title).font(.studio(size: 15, weight: .semibold)).lineLimit(1)
            StudioIcon("chevron.down", size: 9)
              .foregroundStyle(studio.t.muted)
          }.padding(.horizontal, 6).frame(height: 28).hoverFill(studio.t)
        }.padding(.leading, -4).help("Rename or archive this conversation")
      } else {
        Text("New conversation").font(.studio(size: 15, weight: .semibold)).lineLimit(1)
      }
    } trailing: {
      IconMenu(icon: "clock.arrow.circlepath", label: "Conversation history", t: studio.t) {
        ForEach(studio.conversations.prefix(20)) { chat in
          Button(chat.title) { studio.openChat(chat, keepWorkspace: companion) }
        }
        if studio.conversations.isEmpty { Text("No conversations yet") }
        let archived =
          (try? studio.store.conversations(worldID: studio.worldID, archived: true)) ?? []
        if !archived.isEmpty {
          Divider()
          MenuSection("Archived") {
            ForEach(archived) { chat in
              Button("Restore “\(chat.title)”") { studio.restore(conversationID: chat.id) }
            }
          }
        }
      }
      IconButton(icon: "square.and.pencil", label: "New conversation · ⇧⌘N", t: studio.t) {
        studio.newChat(keepWorkspace: companion)
      }
      if companion {
        IconButton(
          icon: "arrow.up.left.and.arrow.down.right", label: "Open in Conversation", t: studio.t
        ) { studio.navigate(.chat) }
        IconButton(icon: "sidebar.right", label: "Hide companion", t: studio.t) {
          withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = false }
        }
      }
    }
  }

  // MARK: Empty state

  @ViewBuilder private func emptyState(narrow: Bool) -> some View {
    VStack(alignment: .leading, spacing: 26) {
      if companion {
        VStack(alignment: .leading, spacing: 8) {
          Text("Think alongside your world").font(.studio(size: 19, weight: .semibold))
          Text(
            studio.mode == .assisted
              ? "Reference a card, develop a connection or ask a question. This is the same conversation you see in the Conversation workspace."
              : "Manual is on, so nothing is sent. Earlier conversations stay readable."
          ).font(.studio(size: 14)).lineSpacing(4).foregroundStyle(studio.t.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 9) {
            WorldBadge(studio: studio, radius: 6).frame(width: 24, height: 24)
            Text(studio.world?.name ?? "Your world").font(.studio(size: 13, weight: .medium))
              .foregroundStyle(studio.t.secondary)
          }
          Text(
            studio.mode == .assisted
              ? "Give your next idea room." : "Conversation is paused in Manual."
          ).font(.studio(size: narrow ? 28 : 38, weight: .semibold)).tracking(-1)
          Text(
            studio.mode == .assisted
              ? "A new character. An impossible place. A rule worth breaking. Start anywhere — your world is here to build on."
              : "No model requests are made. Earlier conversations stay readable, and every other workspace keeps working."
          ).font(.studio(size: 15)).lineSpacing(5).foregroundStyle(studio.t.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  @ViewBuilder private var references: some View {
    if studio.topLevelRecords.isEmpty {
      HStack(spacing: 10) {
        StudioIcon("tray").foregroundStyle(studio.t.muted)
        Text("Your library is empty. Anything you save from a conversation becomes a draft there.")
          .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    } else {
      VStack(alignment: .leading, spacing: 10) {
        SectionLabel(title: "From your world", t: studio.t)
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], alignment: .leading, spacing: 8
        ) {
          ForEach(studio.topLevelRecords.prefix(3)) { record in
            Button {
              studio.reference(record)
            } label: {
              HStack(spacing: 10) {
                CategoryTile(record: record, t: studio.t, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                  Text(record.title).font(.studio(size: 13.5, weight: .medium)).lineLimit(1)
                  Text(
                    record.body.isEmpty
                      ? Vocabulary.displayCategory(record.category)
                      : record.body.replacingOccurrences(of: "\n", with: " ")
                  ).font(.studio(size: 12)).foregroundStyle(studio.t.muted).lineLimit(1)
                }
                Spacer(minLength: 4)
                StudioIcon("at", size: 11).foregroundStyle(studio.t.muted)
              }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(studio.t.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                .hoverFill(studio.t, radius: 10)
            }.buttonStyle(.plain).help("Reference \(record.title) in your message")
              .contextMenu { Button("Open record") { studio.openRecord(record) } }
          }
        }
      }
    }
  }
  private var manualNotice: some View {
    HStack(spacing: 10) {
      StudioIcon("hand.raised").foregroundStyle(studio.t.muted)
      Text("Manual · no model requests").font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
      Spacer()
      Button("Switch to AI Assisted") { studio.setMode(.assisted) }
        .buttonStyle(QuietButton(t: studio.t))
    }.padding(.leading, 14).padding(.trailing, 8).frame(height: 46)
      .background(studio.t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(studio.t.hairline, lineWidth: 1))
  }

  // MARK: Transcript

  private func transcript(narrow: Bool) -> some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          ForEach(studio.messages) { message in
            ChatRow(studio: studio, message: message, narrow: narrow)
          }
          if studio.busy {
            VStack(alignment: .leading, spacing: 12) {
              AIActivityView(steps: studio.activity, t: studio.t)
              if !studio.streamed.isEmpty {
                // A change set arrives as JSON at the end; show prose, not the raw block.
                MarkdownContent(text: ProposalParser.visible(studio.streamed), t: studio.t)
                  .environment(\.openURL, recordLinkAction(studio))
                if studio.streamed.contains(ProposalParser.fence) {
                  StudioLabel("Preparing changes for your review…", icon: "square.stack.3d.up")
                    .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
                }
              }
            }
          }
          Color.clear.frame(height: 1).id("latest")
            .background(TranscriptScrollObserver { followLatest = $0 })
        }.frame(maxWidth: 720, alignment: .leading).padding(.horizontal, narrow ? 18 : 40)
          .padding(.top, 12).padding(.bottom, 20).frame(maxWidth: .infinity)
      }
      .overlay(alignment: .bottomTrailing) {
        if !followLatest {
          Button {
            followLatest = true
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("latest", anchor: .bottom) }
          } label: {
            StudioLabel("Latest", icon: "arrow.down").font(.studio(size: 12.5, weight: .medium))
              .padding(.horizontal, 12).padding(.vertical, 8).floatingPanel(studio.t)
          }.buttonStyle(.plain).padding(16).transition(
            .opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .onAppear { proxy.scrollTo("latest", anchor: .bottom) }
      .onChange(of: studio.messages.count) { _, _ in
        if followLatest {
          withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("latest", anchor: .bottom) }
        }
      }
      .onChange(of: studio.streamed) { _, _ in
        if followLatest { proxy.scrollTo("latest", anchor: .bottom) }
      }
      .onChange(of: studio.conversationID) { _, _ in
        followLatest = true
        proxy.scrollTo("latest", anchor: .bottom)
      }
    }
  }
}

/// Opens `synthesis://record/<id>` links against the selected world only.
@MainActor func recordLinkAction(_ studio: Studio) -> OpenURLAction {
  OpenURLAction { url in
    if url.scheme == "synthesis", url.host == "record",
      let record = studio.records.first(where: { $0.id == url.lastPathComponent })
    {
      studio.openRecord(record)
      return .handled
    }
    if url.scheme == "synthesis" {
      studio.show("That record is not available in this world.", icon: "questionmark.circle")
    }
    return .discarded
  }
}

struct ChatRow: View {
  @ObservedObject var studio: Studio
  let message: ChatMessage
  var narrow = false
  @State private var copied = false
  var body: some View {
    switch message.role {
    case "user": user
    case "system": notice
    default: assistant
    }
  }
  private var user: some View {
    HStack {
      Spacer(minLength: narrow ? 24 : 80)
      Text(
        (try? AttributedString(
          markdown: message.body,
          options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
          ?? AttributedString(message.body)
      )
      .environment(\.openURL, recordLinkAction(studio)).tint(studio.t.accent)
      .font(.studio(size: 15)).lineSpacing(5).textSelection(.enabled)
      .padding(.horizontal, 15).padding(.vertical, 11)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 16))
    }.accessibilityElement(children: .combine).accessibilityLabel("You: \(message.body)")
  }
  private var notice: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      StudioIcon("exclamationmark.circle").foregroundStyle(studio.t.warning)
      Text(message.body).font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Button("Edit & retry") {
        studio.prepareRetry(after: message.id)
      }.buttonStyle(QuietButton(t: studio.t, role: .ghost)).disabled(studio.busy)
      Button("Model settings") { studio.openAssistantSettings() }.buttonStyle(.plain)
        .font(.studio(size: 13, weight: .medium)).foregroundStyle(studio.t.accent)
    }.padding(.horizontal, 14).padding(.vertical, 11)
      .background(studio.t.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(studio.t.hairline, lineWidth: 1))
  }
  private var assistant: some View {
    let sample = message.state == "imported-example"
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        StudioIcon("sparkles", size: 15).foregroundStyle(studio.t.accent)
        Text(sample ? "Imported example" : "Synthesis").font(.studio(size: 13, weight: .semibold))
        Text(
          sample
            ? "Authored sample · not a model response"
            : (message.state == "interrupted"
              ? "Incomplete response" : "Suggestion · not canon")
        )
        .font(.studio(size: 12)).foregroundStyle(studio.t.muted)
      }
      MarkdownContent(text: message.body, t: studio.t)
        .environment(\.openURL, recordLinkAction(studio))
      if let proposal = studio.proposals[message.id] {
        ProposalCard(studio: studio, proposal: proposal, narrow: narrow)
      }
      if let sources = studio.contexts[message.id], !sources.isEmpty {
        ContextDisclosure(studio: studio, sources: sources)
      }
      HStack(spacing: 2) {
        action(copied ? "Copied" : "Copy", copied ? "checkmark" : "doc.on.doc") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(message.body, forType: .string)
          copied = true
          Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
          }
        }
        action("Save as draft", "square.and.arrow.down") { studio.saveResponse(message) }
        action("Save as entity", "circle.hexagongrid") {
          studio.saveResponse(message, entity: true)
        }
      }.padding(.leading, -8)
    }
  }
  private func action(_ title: String, _ icon: String, run: @escaping () -> Void) -> some View {
    Button(action: run) {
      Group {
        if narrow {
          StudioIcon(icon).frame(width: 16)
        } else {
          StudioLabel(title, icon: icon).fixedSize()
        }
      }.font(.studio(size: 12, weight: .medium)).foregroundStyle(studio.t.muted)
        .padding(.horizontal, 8).frame(height: 26).hoverFill(studio.t, radius: 6)
    }.buttonStyle(.plain).accessibilityLabel(title)
      .help(title == "Copy" || title == "Copied" ? "Copy the text" : "\(title) for your review")
  }
}

/// Message composer shared by Conversation, the companion and the compact canvas bar. Keystrokes
/// stay local; the draft is persisted on a short debounce and flushed on disappear.
struct UnifiedComposer: View {
  @ObservedObject var studio: Studio
  var companion = false
  var collapsed = false
  @State private var focused = false
  @State private var text = ""
  @State private var loadedWorld = ""
  @State private var saveTask: Task<Void, Never>?
  @State private var inputHeight: CGFloat = 26
  @State private var referencePicker = false
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
        in: RoundedRectangle(cornerRadius: collapsed ? 18 : 22)
      )
      .overlay(
        RoundedRectangle(cornerRadius: collapsed ? 18 : 22).stroke(
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
    .animation(.easeOut(duration: 0.16), value: focused)
    .animation(.easeOut(duration: 0.16), value: inputHeight)
    .onAppear {
      loadedWorld = studio.worldID
      text = studio.draft
    }
    .onChange(of: studio.draft) { _, value in if value != text { text = value } }
    .onChange(of: text) { _, _ in
      if loadedWorld == studio.worldID { studio.pendingComposer = (loadedWorld, text) }
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
    VStack(spacing: 14) {
      if companion || studio.selectedRecord != nil {
        HStack(spacing: 7) {
          StudioIcon(studio.destination.icon, size: 12)
          Text(studio.contextLabel).lineLimit(1)
          Spacer(minLength: 0)
          Text("World context").foregroundStyle(studio.t.muted)
        }.font(.studio(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
          .padding(.horizontal, 20).padding(.top, 14)
      }
      ComposerInput(
        text: $text,
        placeholder: companion
          ? "Ask about your world…" : "Write freely, or ask about your world…",
        color: studio.t.text, placeholderColor: studio.t.muted, accent: studio.t.accent,
        accentSoft: studio.t.accentSoft, autofocus: !companion,
        sendShortcut: studio.preferences.sendShortcut, handle: handle,
        onFocus: { focused = $0 }, onHeight: { inputHeight = $0 }, onMention: updateMention,
        onMentionKey: mentionKey,
        submit: send
      ).frame(height: min(190, max(companion ? 40 : 64, inputHeight)))
        .padding(.horizontal, 20).padding(.top, 20)
      HStack(spacing: 4) {
        attachment
        references
        modeMenu
        Spacer(minLength: 0)
        if !companion {
          PlainMenu {
            Button("Configure assistant…") { studio.openAssistantSettings() }
            Text("Uses your linked subscription").foregroundStyle(studio.t.muted)
          } label: {
            HStack(spacing: 5) {
              Text(studio.provider.title).font(.studio(size: 12.5, weight: .medium))
              StudioIcon("chevron.down", size: 9)
            }.foregroundStyle(studio.t.secondary).padding(.horizontal, 8).frame(height: 30)
              .hoverFill(studio.t)
          }.help("Assistant settings")
        }
        sendButton
      }.padding(.horizontal, 12).padding(.bottom, 12)
    }
  }
  private var compactField: some View {
    HStack(alignment: .bottom, spacing: 4) {
      attachment.padding(.bottom, 1)
      references.padding(.bottom, 1)
      ComposerInput(
        text: $text,
        placeholder: "Ask about \(studio.contextLabel)…", color: studio.t.text,
        placeholderColor: studio.t.muted, accent: studio.t.accent,
        accentSoft: studio.t.accentSoft, sendShortcut: studio.preferences.sendShortcut,
        handle: handle, onFocus: { focused = $0 }, onHeight: { inputHeight = $0 },
        onMention: updateMention, onMentionKey: mentionKey, submit: send
      ).frame(height: min(96, max(26, inputHeight))).padding(.bottom, 2)
      IconButton(icon: "sidebar.right", label: "Open the companion conversation", t: studio.t) {
        commitDraft()
        withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = true }
      }.padding(.bottom, 1)
      sendButton
    }.padding(.leading, 11).padding(.trailing, 10).padding(.vertical, 12)
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
    IconButton(icon: "paperclip", label: "Attach a text or Markdown file", t: studio.t) {
      commitDraft()
      studio.attachText()
      text = studio.draft
    }
  }
  private var references: some View {
    Button {
      referencePicker = true
    } label: {
      HStack(spacing: 4) {
        StudioIcon("at", size: 13)
        if !collapsed { Text("Lore").font(.studio(size: 13, weight: .medium)) }
      }.foregroundStyle(studio.t.secondary).padding(.horizontal, 7).frame(height: 28)
        .hoverFill(studio.t)
    }.buttonStyle(.plain).help("Reference lore from this world, or type @")
      .popover(isPresented: $referencePicker) {
        SearchableRecordPicker(records: studio.records, t: studio.t) { record in
          handle.insertReference(title: record.title, id: record.id)
          referencePicker = false
        }
      }
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
    guard loadedWorld == studio.worldID else { return }
    studio.pendingComposer = nil
    if studio.draft != text {
      studio.draft = text
      studio.persistComposer()
    }
  }
  private func send() {
    guard studio.mode == .assisted, !studio.busy else { return }
    saveTask?.cancel()
    commitDraft()
    studio.send(keepWorkspace: companion || collapsed)
    text = studio.draft
    if collapsed { withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = true } }
  }
}
