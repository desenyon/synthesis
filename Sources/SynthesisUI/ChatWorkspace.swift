import SwiftUI
import SynthesisCore

struct ChatWorkspace: View {
  @ObservedObject var studio: Studio
  @State private var references = false
  var body: some View {
    GeometryReader { geo in
      let small = geo.size.width < 600
      if studio.messages.isEmpty && !studio.busy {
        ScrollView {
          VStack(spacing: 0) {
            ZStack {
              RadialGradient(
                colors: [studio.t.accent.opacity(studio.dark ? 0.08 : 0.055), .clear],
                center: .center, startRadius: 25, endRadius: 380
              ).frame(height: 430)
              WorldArt(t: studio.t).frame(width: small ? 420 : 660, height: small ? 270 : 400)
                .offset(x: small ? 85 : 195, y: small ? -50 : -40).opacity(small ? 0.55 : 0.8).mask(
                  LinearGradient(
                    colors: [.clear, .black, .black, .clear], startPoint: .top, endPoint: .bottom))
              VStack(spacing: 18) {
                HStack(spacing: 7) {
                  Circle().fill(studio.t.accent).frame(width: 5, height: 5)
                  Text(studio.world?.name ?? "Your world").font(.system(size: 12, weight: .medium))
                  Text("/ a space for possibility").font(.system(size: 12)).foregroundStyle(
                    studio.t.secondary)
                }
                Text("What are we\ncreating today?").font(
                  .system(size: small ? 37 : 49, weight: .regular, design: .serif)
                ).tracking(-1.8).multilineTextAlignment(.center).lineSpacing(-1)
                Text("An entire universe begins with an idea.").font(.system(size: small ? 14 : 16))
                  .foregroundStyle(studio.t.secondary)
              }.padding(.top, small ? 40 : 70)
            }.frame(width: geo.size.width, height: small ? 300 : 340).clipped().padding(
              .top, max(12, (geo.size.height - 760) / 3))
            Composer(studio: studio).frame(maxWidth: 800).padding(.horizontal, small ? 20 : 40)
            suggestions(small: small).frame(maxWidth: 800).padding(.horizontal, small ? 20 : 40)
              .padding(.top, 22)
            HStack(spacing: 6) {
              Image(systemName: "lock.shield").font(.system(size: 11))
              Text("Your world. Your canon. Always in your hands.").font(.system(size: 11))
            }.foregroundStyle(studio.t.muted).padding(.top, 28).padding(.bottom, 40)
          }.frame(width: geo.size.width)
        }
      } else {
        VStack(spacing: 0) {
          HStack {
            Text(
              studio.conversations.first { $0.id == studio.conversationID }?.title
                ?? "New conversation"
            ).font(.system(size: 14, weight: .medium)).lineLimit(1)
            Spacer()
            Button {
              studio.sheet = .rename
            } label: {
              Image(systemName: "pencil")
            }.buttonStyle(.plain).help("Rename conversation")
          }.padding(.horizontal, small ? 24 : 40).padding(.vertical, 20)
          ScrollViewReader { proxy in
            ScrollView {
              VStack(alignment: .leading, spacing: 30) {
                ForEach(studio.messages) { message in ChatRow(studio: studio, message: message) }
                if studio.busy {
                  VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 9) {
                      BrandMark(size: 18, color: studio.t.accent)
                      Text(studio.streamed.isEmpty ? "Thinking with your world…" : "Synthesis")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(
                          studio.t.secondary)
                    }
                    if !studio.streamed.isEmpty {
                      MarkdownContent(text: studio.streamed, t: studio.t)
                    }
                  }.id("stream")
                }
                Color.clear.frame(height: 1).id("bottom")
              }.frame(maxWidth: 800, alignment: .leading).padding(.horizontal, small ? 24 : 40)
                .padding(.vertical, 24).frame(maxWidth: .infinity)
            }.onChange(of: studio.messages.count) { _, _ in
              withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
          }
          Composer(studio: studio).frame(maxWidth: 800).padding(.horizontal, small ? 16 : 40)
            .padding(.top, 12).padding(.bottom, 20)
        }
      }
    }
  }
  private func suggestions(small: Bool) -> some View {
    let items: [(String, String, String)] = [
      (
        "Invent a system", "sparkles",
        "Create a distinctive magic system with clear costs and constraints."
      ),
      (
        "Develop a character", "person.crop.circle",
        "Help me develop a character with conflicting desires."
      ), ("Explore history", "clock", "Explore a defining historical event and its consequences."),
      (
        "Check continuity", "checkmark.shield",
        "Check the world's established lore for contradictions. Cite your sources."
      ),
    ]
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: small ? 2 : 4),
      spacing: 10
    ) {
      ForEach(items, id: \.0) { item in
        Button {
          studio.draft = item.2
          studio.preset = item.0 == "Check continuity" ? "Critique" : "Create"
          studio.persistComposer()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: item.1).font(.system(size: 14)).foregroundStyle(
              studio.t.accent.opacity(0.8))
            Text(item.0).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(
              0.85)
          }.foregroundStyle(studio.t.secondary).frame(maxWidth: .infinity, minHeight: 42)
            .background(studio.t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
              RoundedRectangle(cornerRadius: 12).stroke(
                studio.t.border.opacity(0.6), lineWidth: 0.5))
        }.buttonStyle(.plain)
      }
    }
  }
}
struct Composer: View {
  @ObservedObject var studio: Studio
  @State private var showReferences = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 12) {
        ComposerInput(
          text: $studio.draft, placeholder: "Ask anything about your world…", color: studio.t.text,
          submit: studio.send
        ).frame(height: min(150, max(64, CGFloat(studio.draft.count / 75 + 1) * 22 + 26))).onChange(
          of: studio.draft
        ) { _, _ in studio.persistComposer() }
        HStack(spacing: 14) {
          IconButton(icon: "plus", label: "Attach text or Markdown", t: studio.t) {
            studio.attachText()
          }
          Menu {
            ForEach(studio.records.prefix(30)) { record in
              Button(record.title) {
                studio.draft += " @\(record.title) [synthesis://record/\(record.id)]"
              }
            }
            if studio.records.isEmpty { Text("Create a document or entity in Library first") }
          } label: {
            Label("Lore", systemImage: "at").font(.system(size: 12)).foregroundStyle(
              studio.t.secondary)
          }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
          Rectangle().fill(studio.t.border).frame(width: 1, height: 15)
          Menu {
            ForEach(["Create", "Develop", "Critique", "Simulate", "Canonize"], id: \.self) {
              preset in Button(preset) { studio.preset = preset }
            }
          } label: {
            HStack(spacing: 6) {
              Text(studio.preset)
              Image(systemName: "chevron.down").font(.system(size: 9))
            }.font(.system(size: 12)).foregroundStyle(studio.t.secondary)
          }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
          Spacer(minLength: 4)
          Button {
            if studio.busy { studio.stop() } else { studio.send() }
          } label: {
            Image(systemName: studio.busy ? "stop.fill" : "arrow.up").font(
              .system(size: 16, weight: .medium)
            ).foregroundStyle(
              studio.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.busy
                ? studio.t.muted : Color.white
            ).frame(width: 36, height: 36).background(
              studio.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.busy
                ? studio.t.secondarySurface : studio.t.accent,
              in: RoundedRectangle(cornerRadius: 11))
          }.buttonStyle(.plain).disabled(
            studio.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !studio.busy
          ).accessibilityLabel(studio.busy ? "Stop generation" : "Send message")
        }
      }.padding(20).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 22)).overlay(
        RoundedRectangle(cornerRadius: 22).stroke(studio.t.border.opacity(0.8), lineWidth: 1)
      ).shadow(color: Color.black.opacity(studio.dark ? 0.13 : 0.035), radius: 18, x: 0, y: 7)
      HStack(spacing: 5) {
        if !studio.providerConfigured {
          Image(systemName: "circle.dotted").font(.system(size: 11))
          Button("Connect a model") { studio.sheet = .settings }.buttonStyle(.plain)
            .foregroundStyle(studio.t.accent)
          Text("to start a conversation.").foregroundStyle(studio.t.secondary)
        } else {
          Image(systemName: "arrow.up.right").font(.system(size: 10))
          Text("Sending shares this message and world context with OpenAI.").foregroundStyle(
            studio.t.secondary)
        }
      }.font(.system(size: 11)).padding(.horizontal, 8)
    }
  }
}
struct ChatRow: View {
  @ObservedObject var studio: Studio
  let message: ChatMessage
  var body: some View {
    if message.role == "user" {
      HStack {
        Spacer(minLength: 30)
        Text(message.body).font(.system(size: 15)).lineSpacing(5).textSelection(.enabled).padding(
          .horizontal, 20
        ).padding(.vertical, 15).background(
          studio.t.secondarySurface, in: RoundedRectangle(cornerRadius: 20)
        ).frame(maxWidth: 640, alignment: .trailing)
      }
    } else if message.role == "system" {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "info.circle").foregroundStyle(studio.t.accent)
        VStack(alignment: .leading, spacing: 8) {
          Text(message.body).font(.system(size: 13)).foregroundStyle(studio.t.secondary)
          Button("Model settings") { studio.sheet = .settings }.font(.system(size: 12)).buttonStyle(
            .plain
          ).foregroundStyle(studio.t.accent)
        }
      }.padding(.vertical, 4)
    } else {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 9) {
          BrandMark(size: 20, color: studio.t.accent)
          Text("Synthesis").font(.system(size: 12, weight: .semibold))
          Text("Suggestion · not canon").font(.system(size: 11)).foregroundStyle(studio.t.muted)
        }
        MarkdownContent(text: message.body, t: studio.t).environment(
          \.openURL,
          OpenURLAction { url in
            if url.scheme == "synthesis", url.host == "record",
              let r = studio.records.first(where: { $0.id == url.lastPathComponent })
            {
              studio.openRecord(r)
              return .handled
            }
            return .discarded
          })
        HStack(spacing: 16) {
          Button {
            studio.saveResponse(message)
          } label: {
            Label("Save as draft", systemImage: "square.and.arrow.down")
          }
          Menu {
            Button("Create entity draft") { studio.saveResponse(message, entity: true) }
            Button("Copy") {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(message.body, forType: .string)
            }
          } label: {
            Image(systemName: "ellipsis")
          }
        }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(studio.t.secondary)
      }
    }
  }
}
struct MarkdownContent: View {
  let text: String
  let t: Theme
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(text.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, block in
        Text(
          (try? AttributedString(
            markdown: block, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(block)
        ).font(.system(size: block.hasPrefix("#") ? 20 : 16)).lineSpacing(6).foregroundStyle(t.text)
          .textSelection(.enabled).tint(t.accent).frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
