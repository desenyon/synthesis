import SwiftUI
import SynthesisCore

struct StudioSheet: View {
  @ObservedObject var studio: Studio
  let sheet: Studio.Sheet
  @State private var name = ""
  @State private var kind = "lore"
  @State private var category = ""
  @State private var key = ""
  @State private var model = ""
  @State private var worldName = ""
  @State private var saved = false
  init(studio: Studio, sheet: Studio.Sheet) {
    self.studio = studio
    self.sheet = sheet
    _kind = State(initialValue: studio.newRecordKind)
    _category = State(initialValue: studio.libraryCategory ?? "")
    _model = State(initialValue: studio.modelName)
    _worldName = State(initialValue: studio.world?.name ?? "")
    let target = studio.renameTarget ?? studio.conversationID
    _name = State(
      initialValue: sheet == .rename
        ? (studio.conversations.first { $0.id == target }?.title ?? "") : "")
  }
  private func close() { studio.sheet = nil }
  private var nameIsEmpty: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var body: some View {
    Group {
      switch sheet {
      case .world: world
      case .document: document
      case .rename: rename
      case .settings: settings
      }
    }
  }
  private var world: some View {
    SheetScaffold(
      title: "New world", subtitle: "A name is enough. Everything else can stay open.",
      t: studio.t, width: 400, close: close
    ) {
      FormField(placeholder: "World name", text: $name, t: studio.t) {
        if !nameIsEmpty { studio.createWorld(name) }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create world") { studio.createWorld(name) }
        .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(nameIsEmpty)
    }
  }
  private var document: some View {
    let kinds: [(String, String, String, String)] = [
      ("lore", "Document", "doc.text", "Long-form writing"),
      ("entity", "Entity", "circle.hexagongrid", "A character, place, faction…"),
      ("capture", "Idea", "lightbulb", "A loose thought for later"),
    ]
    let create = {
      studio.createRecord(
        title: name, kind: kind,
        category: kind == "entity" ? category : (kind == "capture" ? "Ideas" : ""))
    }
    return SheetScaffold(
      title: "New record", subtitle: "Saved as a draft. A title is optional.", t: studio.t,
      close: close
    ) {
      HStack(spacing: 8) {
        ForEach(kinds, id: \.0) { item in
          Button {
            kind = item.0
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              Image(systemName: item.2).font(.system(size: 15))
                .foregroundStyle(kind == item.0 ? studio.t.accent : studio.t.secondary)
              Text(item.1).font(.system(size: 13.5, weight: .medium))
              Text(item.3).font(.system(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(2)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 96)
              .background(
                kind == item.0 ? studio.t.accentSoft.opacity(0.6) : studio.t.surface,
                in: RoundedRectangle(cornerRadius: 10)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(
                  kind == item.0 ? studio.t.accent.opacity(0.6) : studio.t.hairline, lineWidth: 1)
              )
              .contentShape(RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).accessibilityAddTraits(kind == item.0 ? .isSelected : [])
        }
      }
      FormField(
        label: "Title", placeholder: kind == "entity" ? "Name" : "Untitled", text: $name,
        t: studio.t, submit: create)
      if kind == "entity" {
        VStack(alignment: .leading, spacing: 6) {
          Text("Type").font(.system(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
          FlowLayout(spacing: 6) {
            ForEach(Vocabulary.categories, id: \.self) { item in
              FilterChip(title: item, selected: category == item, t: studio.t) {
                category = category == item ? "" : item
              }
            }
          }
        }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create draft", action: create).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
  }
  private var rename: some View {
    let apply = {
      studio.perform {
        if let id = studio.renameTarget ?? studio.conversationID {
          try studio.store.renameConversation(worldID: studio.worldID, id: id, title: name)
          try studio.reload()
        }
        studio.renameTarget = nil
        studio.sheet = nil
      }
    }
    return SheetScaffold(title: "Rename conversation", t: studio.t, width: 400, close: close) {
      FormField(placeholder: "Conversation name", text: $name, t: studio.t) {
        if !nameIsEmpty { apply() }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Rename", action: apply).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(nameIsEmpty)
    }
  }
  private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 10) {
      SectionLabel(title: title, t: studio.t)
      VStack(alignment: .leading, spacing: 12) { content() }.padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(studio.t.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(studio.t.hairline, lineWidth: 1))
    }
  }
  private func settingRow<Trailing: View>(
    _ title: String, _ detail: String? = nil, @ViewBuilder trailing: () -> Trailing
  ) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.system(size: 13.5, weight: .medium))
        if let detail {
          Text(detail).font(.system(size: 12)).foregroundStyle(studio.t.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 8)
      trailing()
    }
  }
  private var settings: some View {
    SheetScaffold(title: "Settings", t: studio.t, width: 520, close: close) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          group("Appearance") {
            settingRow("Theme") {
              HStack(spacing: 2) {
                ForEach([("Dark", true), ("Light", false)], id: \.0) { item in
                  Button {
                    if studio.dark != item.1 { studio.toggleTheme() }
                  } label: {
                    Text(item.0).font(.system(size: 12.5, weight: .medium))
                      .padding(.horizontal, 12).frame(height: 24)
                      .foregroundStyle(studio.dark == item.1 ? studio.t.text : studio.t.muted)
                      .background(
                        studio.dark == item.1 ? studio.t.secondarySurface : .clear,
                        in: RoundedRectangle(cornerRadius: 6)
                      )
                      .contentShape(Rectangle())
                  }.buttonStyle(.plain)
                }
              }.padding(2).background(studio.t.background, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(studio.t.hairline, lineWidth: 1))
            }
          }
          group("This world") {
            HStack(alignment: .bottom, spacing: 8) {
              FormField(label: "Name", placeholder: "World name", text: $worldName, t: studio.t) {
                studio.renameWorld(worldName)
              }
              Button("Rename") { studio.renameWorld(worldName) }
                .buttonStyle(QuietButton(t: studio.t)).padding(.bottom, 2)
                .disabled(
                  worldName.trimmingCharacters(in: .whitespaces).isEmpty
                    || worldName == studio.world?.name)
            }
            settingRow("Cover image", "Optional. Stored on this device only.") {
              WorldBadge(studio: studio, radius: 6).frame(width: 30, height: 30)
              Button("Choose…") { studio.chooseWorldCover() }.buttonStyle(QuietButton(t: studio.t))
              if studio.worldCover != nil {
                Button("Remove") { studio.removeWorldCover() }
                  .buttonStyle(QuietButton(t: studio.t, role: .ghost))
              }
            }
            settingRow(
              "Export",
              "Markdown: one readable file per record. JSON: everything, including history, proposals and the archive."
            ) {
              Button("Markdown…") { studio.exportMarkdown() }.buttonStyle(QuietButton(t: studio.t))
              Button("JSON…") { studio.exportWorld() }.buttonStyle(QuietButton(t: studio.t))
            }
            settingRow(
              "Import", "Markdown or text files become draft documents marked as imported."
            ) {
              Button("Choose files…") {
                studio.sheet = nil
                studio.importDocuments()
              }.buttonStyle(QuietButton(t: studio.t))
            }
          }
          group("Assistant") {
            HStack(spacing: 8) {
              Circle().fill(studio.providerConfigured ? studio.t.positive : studio.t.muted)
                .frame(width: 7, height: 7)
              Text(
                studio.providerConfigured
                  ? "Connected to OpenAI · \(studio.modelName)" : "No model connected"
              ).font(.system(size: 13.5, weight: .medium))
            }
            Text(
              "Optional. Every manual tool works without a provider. A request is made only when you send a message; it shares that message and context from the selected world with OpenAI."
            ).font(.system(size: 12.5)).foregroundStyle(studio.t.secondary).lineSpacing(3)
              .fixedSize(horizontal: false, vertical: true)
            FormField(
              label: "API key · kept in macOS Keychain",
              placeholder: studio.providerConfigured
                ? "Stored — leave blank to keep it" : "OpenAI API key", text: $key, t: studio.t,
              secure: true)
            FormField(
              label: "Model ID", placeholder: "A model available to your account", text: $model,
              t: studio.t)
            HStack(spacing: 8) {
              Button("Save connection") { saveConnection() }
                .buttonStyle(QuietButton(t: studio.t, primary: true))
                .disabled(
                  model.trimmingCharacters(in: .whitespaces).isEmpty
                    || (key.isEmpty && !ProviderKeychain.configured))
              if studio.providerConfigured {
                Button("Disconnect") {
                  studio.stop()
                  studio.perform {
                    try ProviderKeychain.remove()
                    studio.providerConfigured = false
                    saved = false
                  }
                }.buttonStyle(QuietButton(t: studio.t, role: .danger))
              }
              if saved {
                Label("Saved. No request was made.", systemImage: "checkmark")
                  .font(.system(size: 12.5)).foregroundStyle(studio.t.positive)
              }
            }
          }
          if !studio.worlds.contains(where: { $0.demo }) {
            group("Sample") {
              settingRow(
                "Aster, a sample universe",
                "A clearly labelled world to explore. Your own worlds are not changed."
              ) {
                Button("Open sample") {
                  studio.loadSample()
                  close()
                }.buttonStyle(QuietButton(t: studio.t))
              }
            }
          }
        }.padding(.bottom, 4)
      }.frame(maxHeight: 520)
    } footer: {
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, primary: true))
    }
  }
  private func saveConnection() {
    studio.perform {
      if !key.isEmpty { try ProviderKeychain.save(key) }
      let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
      try studio.store.setPreference("model", value: value)
      studio.modelName = value
      UserDefaults.standard.set(value, forKey: "Synthesis.model")
      studio.providerConfigured = ProviderKeychain.configured && !value.isEmpty
      key = ""
      saved = true
    }
  }
}
