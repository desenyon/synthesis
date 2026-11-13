import SwiftUI
import SynthesisCore

struct ConversationStudio: View {
  @ObservedObject var studio: Studio
  var companion = false
  var body: some View {
    GeometryReader { geo in
      let narrow = companion || geo.size.width < 600
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          Image(systemName: "bubble.left.and.bubble.right").foregroundStyle(studio.t.accent)
          Text(
            studio.conversations.first { $0.id == studio.conversationID }?.title
              ?? "New conversation"
          )
          .font(.system(size: 15, weight: .medium)).lineLimit(1)
          Spacer()
          Menu {
            Button("New conversation") {
              studio.newChat(keepWorkspace: companion)
            }
            ForEach(studio.conversations) { chat in
              Button(chat.title) {
                studio.openChat(chat, keepWorkspace: companion)
              }
            }
            if studio.conversationID != nil {
              Button("Rename conversation…") { studio.sheet = .rename }
            }
          } label: {
            Image(systemName: "clock.arrow.circlepath")
          }
          .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help(
            "Conversation history")
          if companion {
            IconButton(
              icon: "arrow.up.left.and.arrow.down.right", label: "Open full conversation",
              t: studio.t
            ) { studio.navigate(.chat) }
            IconButton(icon: "xmark", label: "Collapse companion", t: studio.t) {
              withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = false }
            }
          } else if studio.conversationID != nil {
            IconButton(icon: "square.and.pencil", label: "New conversation", t: studio.t) {
              studio.newChat()
            }
          }
        }.padding(.horizontal, narrow ? 20 : 32).frame(height: 56)
        if studio.messages.isEmpty && !studio.busy {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              if !companion {
                WorldBadge(studio: studio).frame(
                  width: studio.worldCover == nil ? 72 : 220,
                  height: studio.worldCover == nil ? 72 : 100)
                VStack(alignment: .leading, spacing: 12) {
                  Text(studio.world?.name ?? "Your universe").font(
                    .system(size: 14, weight: .medium)
                  ).foregroundStyle(studio.t.accent)
                  Text(
                    studio.mode == .manual
                      ? "Your conversations, kept close." : "Give your next idea room."
                  )
                  .font(.system(size: narrow ? 28 : 36, weight: .medium)).tracking(-0.6)
                  Text(
                    studio.mode == .manual
                      ? "History remains available. Switch to AI Assisted when you want to continue a conversation."
                      : "Explore a possibility, question a rule, or bring a whole page of thoughts. Your lore is here when you need it."
                  )
                  .font(.system(size: 16)).lineSpacing(6).foregroundStyle(studio.t.secondary)
                  .fixedSize(horizontal: false, vertical: true)
                }
                if !studio.records.isEmpty {
                  VStack(alignment: .leading, spacing: 12) {
                    Text("From your world").font(.system(size: 13, weight: .medium))
                      .foregroundStyle(studio.t.secondary)
                    ForEach(studio.records.prefix(3)) { record in
                      Button {
                        studio.openRecord(record)
                      } label: {
                        HStack(spacing: 12) {
                          Image(systemName: categoryIcon(record.category)).foregroundStyle(
                            studio.t.accent
                          ).frame(width: 20)
                          VStack(alignment: .leading, spacing: 4) {
                            Text(record.title).font(.system(size: 15, weight: .medium))
                            Text(record.body.isEmpty ? record.category : record.body).font(
                              .system(size: 13)
                            ).foregroundStyle(studio.t.secondary).lineLimit(1)
                          }
                          Spacer()
                          Image(systemName: "arrow.up.right").font(.system(size: 12))
                            .foregroundStyle(studio.t.muted)
                        }.padding(14).background(
                          studio.t.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                      }.buttonStyle(.plain)
                    }
                  }.padding(.top, 8)
                }
              } else {
                Text("Think alongside your canvas").font(.system(size: 23, weight: .medium))
                Text(
                  "Reference an entity, develop a connection, or ask a question. The same conversation follows you into the full workspace."
                )
                .font(.system(size: 15)).lineSpacing(5).foregroundStyle(studio.t.secondary)
              }
            }.frame(maxWidth: 720, alignment: .leading).padding(narrow ? 24 : 48)
              .padding(.top, companion ? 20 : max(20, (geo.size.height - 700) / 3)).frame(
                maxWidth: .infinity)
          }.clipped()
        } else {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(alignment: .leading, spacing: 32) {
                ForEach(studio.messages) { message in ChatRow(studio: studio, message: message) }
                if studio.busy {
                  VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                      ProgressView().controlSize(.small)
                      Text(studio.streamed.isEmpty ? "Waiting for model…" : "Responding…").font(
                        .system(size: 13)
                      ).foregroundStyle(studio.t.secondary)
                    }
                    if !studio.streamed.isEmpty {
                      MarkdownContent(text: studio.streamed, t: studio.t)
                    }
                  }
                }
                Color.clear.frame(height: 1).id("latest")
              }.frame(maxWidth: 760, alignment: .leading).padding(narrow ? 20 : 36).frame(
                maxWidth: .infinity)
            }.onChange(of: studio.messages.count) { _, _ in
              withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("latest", anchor: .bottom) }
            }
          }.clipped()
        }
        if studio.mode == .assisted {
          UnifiedComposer(studio: studio, companion: companion).frame(maxWidth: 800)
            .padding(.horizontal, narrow ? 16 : 32).padding(.bottom, 20)
        } else {
          HStack {
            Image(systemName: "hand.draw")
            Text("Manual · model requests are off")
            Spacer()
            Button("Open library") { studio.navigate(.library) }
          }
          .font(.system(size: 13)).foregroundStyle(studio.t.secondary).padding(24)
        }
      }
    }.background(studio.t.background)
  }
}

struct UnifiedComposer: View {
  @ObservedObject var studio: Studio
  var companion = false
  var collapsed = false
  @State private var text = ""
  @State private var loadedWorld = ""
  @State private var saveTask: Task<Void, Never>?
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(spacing: 8) {
        if collapsed {
          HStack(spacing: 8) {
            attachment
            ComposerInput(
              text: $text, placeholder: "Ask about your canvas…", color: studio.t.text, submit: send
            ).frame(height: 30)
            references
            IconButton(
              icon: "arrow.up.left.and.arrow.down.right", label: "Expand companion chat",
              t: studio.t
            ) {
              commitDraft()
              withAnimation(.easeOut(duration: 0.18)) { studio.companionExpanded = true }
            }
            sendButton
          }.padding(10)
        } else {
          ComposerInput(
            text: $text,
            placeholder: "Write freely. @ Lore brings your world into the conversation…",
            color: studio.t.text, submit: send
          )
          .frame(height: min(160, max(64, CGFloat(text.count / 70 + 1) * 22))).padding(
            .horizontal, 16
          ).padding(.top, 16)
          HStack(spacing: 12) {
            attachment
            references
            Menu {
              ForEach(["Create", "Develop", "Critique", "Simulate", "Canonize"], id: \.self) {
                preset in Button(preset) { studio.preset = preset }
              }
              Divider()
              Menu("Optional guided prompts") {
                ForEach(StudioModule.defaults.filter { $0.id != "overview" }) { module in
                  Button(module.title) {
                    text =
                      "Help me explore \(module.title.lowercased()). Ask one question at a time, follow my direction, and keep all ideas hypothetical until I accept them."
                  }
                }
              }
            } label: {
              Text(studio.preset).font(.system(size: 13))
            }
            .menuStyle(.borderlessButton).fixedSize()
            Spacer(minLength: 0)
            sendButton
          }.padding(.horizontal, 12).padding(.bottom, 12)
        }
      }.background(studio.t.surface, in: RoundedRectangle(cornerRadius: collapsed ? 14 : 18))
        .overlay(
          RoundedRectangle(cornerRadius: collapsed ? 14 : 18).stroke(
            studio.t.border.opacity(0.8), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(studio.dark ? 0.14 : 0.04), radius: 16, y: 4)
      if !collapsed {
        HStack(spacing: 6) {
          if studio.providerConfigured {
            Image(systemName: "arrow.up.right")
            Text("Sending shares this message and world context with OpenAI.")
          } else {
            Image(systemName: "circle.dotted")
            Button("Connect a model") { studio.sheet = .settings }.buttonStyle(.plain)
              .foregroundStyle(studio.t.accent)
            Text("or keep a message for later.")
          }
        }.font(.system(size: 12)).foregroundStyle(studio.t.secondary).padding(.horizontal, 6)
      }
      if collapsed {
        HStack(spacing: 5) {
          if studio.providerConfigured {
            Text("Sending shares your message and world context with OpenAI")
          } else {
            Button("Connect a model") { studio.sheet = .settings }.buttonStyle(.plain)
            Text("· messages stay local until sent")
          }
        }.font(.system(size: 11)).foregroundStyle(studio.t.secondary).padding(.horizontal, 6)
      }
    }.onAppear {
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
  private var attachment: some View {
    IconButton(icon: "plus", label: "Attach text or Markdown", t: studio.t) {
      commitDraft()
      studio.attachText()
      text = studio.draft
    }
  }
  private var references: some View {
    Menu {
      ForEach(studio.records) { record in
        Button(record.title) { text += " [\(record.title)](synthesis://record/\(record.id)) " }
      }
      if studio.records.isEmpty { Text("Create a record in Library first") }
    } label: {
      Text(collapsed ? "@" : "@ Lore").font(.system(size: 13, weight: .medium))
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Reference world lore")
  }
  private var sendButton: some View {
    Button {
      if studio.busy { studio.stop() } else { send() }
    } label: {
      Image(systemName: studio.busy ? "stop.fill" : "arrow.up").font(
        .system(size: 15, weight: .medium)
      )
      .frame(width: 32, height: 32).foregroundStyle(studio.t.background)
      .background(
        studio.t.accent.opacity(
          text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.busy ? 0.25 : 1),
        in: Circle())
    }.buttonStyle(.plain).disabled(
      (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.busy)
        || studio.mode == .manual
    )
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
