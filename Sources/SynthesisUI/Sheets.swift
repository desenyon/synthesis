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
    _model = State(
      initialValue: studio.provider.usesSubscription
        ? (studio.harnessModels[studio.provider] ?? "") : studio.modelName)
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
          group("Assistant") { assistant }
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
  /// Provider choice. A local harness signed in with a subscription is the default; an API
  /// key is available for those who prefer it. Synthesis never sees harness credentials.
  @ViewBuilder private var assistant: some View {
    let t = studio.t
    Text(
      "Optional — every manual tool works without it. A request is made only when you send a message."
    ).font(.system(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
    VStack(spacing: 6) {
      ForEach(ProviderKind.allCases) { kind in
        let selected = studio.provider == kind
        Button {
          studio.setProvider(kind)
          if kind.usesSubscription { studio.checkProvider() }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
              .font(.system(size: 14)).foregroundStyle(selected ? t.accent : t.muted)
            VStack(alignment: .leading, spacing: 2) {
              Text(kind.title).font(.system(size: 13.5, weight: .medium))
              Text(
                kind == .claudeCode
                  ? "Uses your Claude subscription through the Claude Code app on this Mac"
                  : kind == .codex
                    ? "Uses your ChatGPT subscription through Codex on this Mac"
                    : "Pay-as-you-go with your own key, kept in macOS Keychain"
              ).font(.system(size: 12)).foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if kind.usesSubscription && HarnessLocator.find(kind) == nil {
              Text("Not installed").font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(t.muted)
            } else if kind == ProviderKind.allCases.first(where: { HarnessLocator.find($0) != nil })
            {
              Text("Recommended").font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(t.accent)
            }
          }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(
              selected ? t.accentSoft.opacity(0.5) : t.background.opacity(0.5),
              in: RoundedRectangle(cornerRadius: 9)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 9).stroke(
                selected ? t.accent.opacity(0.5) : t.hairline, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    if studio.provider.usesSubscription { harness } else { apiKey }
  }
  @ViewBuilder private var harness: some View {
    let t = studio.t
    let kind = studio.provider
    let installed = HarnessLocator.find(kind) != nil
    HStack(spacing: 8) {
      Circle().fill(
        !installed
          ? t.muted
          : (studio.providerStatus.map { $0.signedIn ? t.positive : t.warning } ?? t.accent)
      ).frame(width: 7, height: 7)
      Text(
        !installed
          ? "\(kind.title) was not found"
          : (studio.providerStatus?.detail ?? "Installed · sign-in not checked yet")
      ).font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      if installed {
        Button(studio.checkingProvider ? "Checking…" : "Check sign-in") { studio.checkProvider() }
          .buttonStyle(QuietButton(t: t)).disabled(studio.checkingProvider)
          .help("Asks \(kind.title) for its status. No message is sent.")
      }
    }
    Text(
      !installed
        ? "Install \(kind.title), open Terminal and run `\(kind == .claudeCode ? "claude" : "codex login")` to sign in, then come back here."
        : kind == .claudeCode
          ? "Synthesis starts Claude Code for each message with all tools, plugins and settings files turned off, in an empty folder. It can only read what you send and write text. Your sign-in stays inside Claude Code."
          : "Synthesis starts Codex for each message in a read-only sandbox and an empty folder, without your Codex config, rules, apps or plugins. Your sign-in stays inside Codex."
    ).font(.system(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
    if installed {
      HStack(alignment: .bottom, spacing: 8) {
        FormField(
          label: "Model (optional)",
          placeholder: kind == .claudeCode
            ? "Leave empty for your default, or sonnet, opus, haiku…"
            : "Leave empty for your default", text: $model, t: t
        ) { studio.setHarnessModel(model, for: kind) }
        Button("Save") {
          studio.setHarnessModel(model, for: kind)
          saved = true
        }.buttonStyle(QuietButton(t: t)).padding(.bottom, 2)
          .disabled(
            model.trimmingCharacters(in: .whitespaces) == (studio.harnessModels[kind] ?? ""))
      }.onChange(of: studio.provider) { _, value in
        model = value.usesSubscription ? (studio.harnessModels[value] ?? "") : studio.modelName
        saved = false
      }
    }
  }
  @ViewBuilder private var apiKey: some View {
    let t = studio.t
    HStack(spacing: 8) {
      Circle().fill(studio.providerConfigured ? t.positive : t.muted).frame(width: 7, height: 7)
      Text(
        studio.providerConfigured ? "Connected to OpenAI · \(studio.modelName)" : "No key connected"
      ).font(.system(size: 13, weight: .medium))
    }
    FormField(
      label: "API key · kept in macOS Keychain",
      placeholder: ProviderKeychain.configured
        ? "Stored — leave blank to keep it" : "OpenAI API key",
      text: $key, t: t, secure: true)
    FormField(
      label: "Model ID", placeholder: "A model available to your account", text: $model, t: t)
    HStack(spacing: 8) {
      Button("Save connection") { saveConnection() }
        .buttonStyle(QuietButton(t: t, primary: true))
        .disabled(
          model.trimmingCharacters(in: .whitespaces).isEmpty
            || (key.isEmpty && !ProviderKeychain.configured))
      if ProviderKeychain.configured {
        Button("Remove key") {
          studio.stop()
          studio.perform {
            try ProviderKeychain.remove()
            studio.refreshProviderAvailability()
            saved = false
          }
        }.buttonStyle(QuietButton(t: t, role: .danger))
      }
      if saved {
        Label("Saved. No request was made.", systemImage: "checkmark")
          .font(.system(size: 12.5)).foregroundStyle(t.positive)
      }
    }.onChange(of: studio.provider) { _, value in
      model = value.usesSubscription ? (studio.harnessModels[value] ?? "") : studio.modelName
      saved = false
    }
  }
  private func saveConnection() {
    studio.perform {
      if !key.isEmpty { try ProviderKeychain.save(key) }
      let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
      try studio.store.setPreference("model", value: value)
      studio.modelName = value
      UserDefaults.standard.set(value, forKey: "Synthesis.model")
      studio.refreshProviderAvailability()
      key = ""
      saved = true
    }
  }
}
