import SwiftUI
import SynthesisCore

struct StudioSheet: View {
  @ObservedObject var studio: Studio
  let sheet: Studio.Sheet
  var embedded = false
  @State private var name = ""
  @State private var kind = "lore"
  @State private var category = ""
  @State private var model = ""
  @State private var worldName = ""
  @State private var worldDescription = ""
  @State private var saved = false
  init(studio: Studio, sheet: Studio.Sheet, embedded: Bool = false) {
    self.embedded = embedded
    self.studio = studio
    self.sheet = sheet
    _kind = State(initialValue: studio.newRecordKind)
    _category = State(initialValue: studio.libraryCategory ?? "")
    _model = State(
      initialValue: studio.harnessModels[studio.provider] ?? "")
    _worldName = State(initialValue: studio.world?.name ?? "")
    _worldDescription = State(initialValue: studio.world?.description ?? "")
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
      case .onboarding: onboarding
      }
    }
  }
  private func finishSetup() { studio.completeOnboarding() }
  private var onboarding: some View {
    SheetScaffold(
      title: "Welcome to Synthesis",
      subtitle: "Your universe, your way. You can change these choices in Settings.", t: studio.t,
      width: 560, close: finishSetup
    ) {
      FormField(label: "Your first world", placeholder: "World name", text: $worldName, t: studio.t)
      HStack {
        Text("Start creating").font(.studio(size: 14, weight: .medium))
        Spacer()
        Button("AI Assisted") { studio.setMode(.assisted) }
          .buttonStyle(QuietButton(t: studio.t, primary: studio.mode == .assisted))
        Button("Manual") { studio.setMode(.manual) }
          .buttonStyle(QuietButton(t: studio.t, primary: studio.mode == .manual))
      }
      HStack {
        Text("Appearance").font(.studio(size: 14, weight: .medium))
        Spacer()
        AppearanceButton(studio: studio)
      }
      if studio.mode == .assisted {
        assistant
      }
      Text(
        "Nothing is generated automatically. Image generation is not available in this build; requested image generation will use your subscription allowance when connected."
      )
      .font(.studio(size: 12)).foregroundStyle(studio.t.secondary).fixedSize(
        horizontal: false, vertical: true)
    } footer: {
      Spacer()
      Button("Start creating") {
        studio.renameWorld(worldName)
        if studio.error == nil { studio.completeOnboarding() }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
              StudioIcon(item.2, size: 15)
                .foregroundStyle(kind == item.0 ? studio.t.accent : studio.t.secondary)
              Text(item.1).font(.studio(size: 13.5, weight: .medium))
              Text(item.3).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(2)
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
          Text("Type").font(.studio(size: 12, weight: .medium)).foregroundStyle(studio.t.secondary)
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
        Text(title).font(.studio(size: 13.5, weight: .medium))
        if let detail {
          Text(detail).font(.studio(size: 12)).foregroundStyle(studio.t.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 8)
      trailing()
    }
  }
  @ViewBuilder private var settings: some View {
    if embedded {
      VStack(spacing: 0) {
        WorkspaceBar(studio: studio) {
          Text("Settings").font(.studio(size: 15, weight: .semibold))
        } trailing: {
        }
        ContentColumn { settingsContents }.padding(.vertical, 20)
      }
    } else {
      SheetScaffold(title: "Settings", t: studio.t, width: 600, close: close) {
        settingsContents.frame(maxHeight: 520)
      } footer: {
        Spacer()
        Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    }
  }
  private var settingsContents: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        group("Application · Assistant") { assistant }
        group("Application · Appearance") {
          settingRow("Theme", studio.dark ? "Dark" : "Light") {
            AppearanceButton(studio: studio)
          }
        }
        group("This world") {
          settingRow("Images", "Export the saved artwork from this world's boards and cover.") {
            Button("Export images…") { studio.exportWorldImages() }.buttonStyle(
              QuietButton(t: studio.t))
          }
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
          HStack(alignment: .bottom, spacing: 8) {
            FormField(
              label: "Description", placeholder: "What makes this world yours",
              text: $worldDescription, t: studio.t)
            Button("Save") {
              studio.perform {
                try studio.store.setWorldDescription(
                  worldID: studio.worldID, description: worldDescription)
                try studio.reload()
                worldDescription = studio.world?.description ?? ""
              }
            }.buttonStyle(QuietButton(t: studio.t)).padding(.bottom, 2)
              .disabled(worldDescription == studio.world?.description)
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
            Button("World file…") { studio.savePortableWorld() }.buttonStyle(
              QuietButton(t: studio.t))
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
    }
  }
  /// Subscription connections remain owned by the installed harness; no keys enter Synthesis.
  @ViewBuilder private var assistant: some View {
    let t = studio.t
    Text(
      "Optional — every manual tool works without it. A request is made only when you send a message."
    ).font(.studio(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
    VStack(spacing: 6) {
      ForEach(ProviderKind.allCases) { kind in
        let selected = studio.provider == kind
        Button {
          studio.setProvider(kind)
          studio.checkProvider()
        } label: {
          HStack(spacing: 10) {
            StudioIcon(selected ? "largecircle.fill.circle" : "circle")
              .font(.studio(size: 14)).foregroundStyle(selected ? t.accent : t.muted)
            VStack(alignment: .leading, spacing: 2) {
              Text(kind.title).font(
                .studio(size: 13.5, weight: .medium))
              Text(
                kind == .claudeCode
                  ? "Uses your Claude subscription through the Claude Code app on this Mac"
                  : "Uses your ChatGPT subscription through Codex on this Mac"
              ).font(.studio(size: 12)).foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if HarnessLocator.find(kind) == nil {
              Text("Not installed").font(.studio(size: 11.5, weight: .medium))
                .foregroundStyle(t.muted)
            } else if kind == .codex {
              Text("Recommended").font(.studio(size: 11.5, weight: .medium))
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
    harness
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
      ).font(.studio(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
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
    ).font(.studio(size: 12.5)).foregroundStyle(t.secondary).lineSpacing(3)
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
        model = studio.harnessModels[value] ?? ""
        saved = false
      }
    }
  }
}
