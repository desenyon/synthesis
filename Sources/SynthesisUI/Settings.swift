import SwiftUI
import SynthesisCore

struct SettingsScreen: View {
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var t: Theme { studio.t }
  private var searching: Bool {
    !studio.settingsQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  private var matches: [SettingsItem] {
    SettingsItem.matching(studio.settingsQuery, section: studio.settingsSection)
  }
  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        Text("Settings").font(.studio(size: 15, weight: .semibold))
      } trailing: {
      }
      GeometryReader { geometry in
        let wide = geometry.size.width >= 860
        VStack(spacing: 0) {
          HStack(spacing: 16) {
            if !wide {
              PreferenceMenu(
                title: "Settings section", value: sectionBinding,
                options: SettingsSection.allCases.map { ($0, $0.rawValue) }, t: t)
            }
            HStack(spacing: 8) {
              StudioIcon("magnifyingglass", size: 14).foregroundStyle(t.secondary)
              TextField("Search settings", text: $studio.settingsQuery)
                .textFieldStyle(.plain).font(.studio(size: 13.5))
                .accessibilityLabel("Search settings")
              if !studio.settingsQuery.isEmpty {
                IconButton(icon: "xmark", label: "Clear search", t: t, size: 22) {
                  studio.settingsQuery = ""
                }
              }
            }.padding(.horizontal, 12).frame(height: 36)
              .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
              .overlay(
                RoundedRectangle(cornerRadius: Metric.radius).stroke(t.hairline, lineWidth: 1)
              )
              .frame(maxWidth: wide ? 320 : .infinity)
            if wide { Spacer() }
          }.padding(.horizontal, wide ? 28 : 24).padding(.top, 24).padding(.bottom, 20)
          HStack(alignment: .top, spacing: 0) {
            if wide { navigation.frame(width: 176).padding(.leading, 24).padding(.trailing, 24) }
            ScrollViewReader { proxy in
              ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                  if searching {
                    heading(
                      "Search results", "\(matches.count) settings match “\(studio.settingsQuery)”."
                    )
                    if matches.isEmpty {
                      VStack(alignment: .leading, spacing: 12) {
                        Text("Try a setting such as spelling, model or export.")
                          .font(.studio(size: 14)).foregroundStyle(t.secondary)
                        Button("Clear search") { studio.settingsQuery = "" }
                          .buttonStyle(QuietButton(t: t))
                      }.padding(.vertical, 24)
                    }
                    ForEach(SettingsSection.allCases) { section in
                      let items = matches.filter { $0.section == section }
                      if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                          Text(section.rawValue).font(.studio(.cardTitle))
                            .padding(.bottom, 8)
                          ForEach(items) { item in setting(item) }
                        }
                      }
                    }
                  } else {
                    heading(studio.settingsSection.rawValue, studio.settingsSection.detail)
                    if studio.settingsSection == .writing { writingPreview }
                    VStack(alignment: .leading, spacing: 0) {
                      ForEach(matches) { item in setting(item) }
                    }
                    Text(
                      studio.settingsSection == .world
                        ? "Defaults apply to new work. Existing lore stays as you wrote it."
                        : studio.settingsSection == .data
                          ? "Exports never include device preferences or provider credentials."
                          : studio.settingsSection == .assistant
                            ? "Provider preferences apply on this Mac. Nothing is generated automatically."
                            : "Preferences are saved on this Mac as you change them."
                    ).font(.studio(.caption)).foregroundStyle(t.muted)
                  }
                }.id("top").frame(maxWidth: 720, alignment: .leading)
                  .padding(.horizontal, wide ? 32 : 24).padding(.bottom, 40)
                  .frame(maxWidth: .infinity, alignment: .topLeading)
              }.onChange(of: studio.settingsSection) { _, _ in proxy.scrollTo("top", anchor: .top) }
                .onChange(of: studio.settingsQuery) { _, query in
                  proxy.scrollTo("top", anchor: .top)
                  if ["model", "privacy"].contains(where: {
                    query.localizedCaseInsensitiveContains($0)
                  }) {
                    studio.assistantSettingsExpanded = true
                  }
                }
            }
          }
        }
      }
    }.foregroundStyle(t.text).background(t.background)
  }
  private var sectionBinding: Binding<SettingsSection> {
    Binding(
      get: { studio.settingsSection },
      set: { section in
        studio.settingsQuery = ""
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
          studio.settingsSection = section
        }
      })
  }
  private var navigation: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(SettingsSection.allCases) { section in
        Button {
          sectionBinding.wrappedValue = section
        } label: {
          HStack(spacing: 10) {
            StudioIcon(section.icon, size: 16)
            Text(section.rawValue).font(.studio(.control))
            Spacer()
          }.foregroundStyle(studio.settingsSection == section && !searching ? t.text : t.secondary)
            .padding(.horizontal, 12).frame(height: 40)
            .hoverFill(t, selected: studio.settingsSection == section && !searching)
        }.buttonStyle(.plain)
          .accessibilityAddTraits(
            studio.settingsSection == section && !searching ? .isSelected : [])
      }
      Text("This Mac · current world").font(.studio(size: 11.5)).foregroundStyle(t.muted)
        .padding(.horizontal, 12).padding(.top, 20)
    }
  }
  private func heading(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.studio(.title)).accessibilityAddTraits(.isHeader)
      Text(subtitle).font(.studio(size: 14)).foregroundStyle(t.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
  private func preference<Value>(_ key: WritableKeyPath<StudioPreferences, Value>) -> Binding<Value>
  {
    Binding(
      get: { studio.preferences[keyPath: key] },
      set: { value in
        studio.updatePreferences { $0[keyPath: key] = value }
      })
  }
  private func toggle(_ item: SettingsItem, _ key: WritableKeyPath<StudioPreferences, Bool>)
    -> some View
  {
    row(item) {
      Toggle(item.title, isOn: preference(key)).labelsHidden().toggleStyle(.switch)
        .controlSize(.small).tint(t.accent)
    }
  }
  private func row<Control: View>(
    _ item: SettingsItem, @ViewBuilder control: @escaping () -> Control
  )
    -> some View
  {
    PreferenceRow(title: item.title, detail: item.detail, t: t, control: control)
  }
  @ViewBuilder private func setting(_ item: SettingsItem) -> some View {
    switch item {
    case .appearance: row(item) { AppearanceSwitch(studio: studio) }
    case .darkPalette:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.darkPalette),
          options: [(.graphite, "Graphite"), (.oled, "True black · OLED")], t: t)
      }
    case .sidebar:
      row(item) {
        Toggle(
          item.title,
          isOn: Binding(
            get: { !studio.collapsed },
            set: { value in
              if value == studio.collapsed { studio.toggleSidebar() }
            })
        ).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(t.accent)
      }
    case .counts: toggle(item, \.sidebarCounts)
    case .previews: toggle(item, \.libraryPreviews)
    case .recents:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.recentChats),
          options: [
            (0, "Hidden"), (5, "5 conversations"), (12, "12 conversations"),
            (20, "20 conversations"),
          ], t: t)
      }
    case .launch:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.launchWorkspace),
          options: [
            ("remember", "Last workspace"), ("Conversation", "Conversation"), ("Canvas", "Canvas"),
            ("Library", "Library"), ("Worlds", "Your worlds"),
          ], t: t)
      }
    case .textSize:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.bodySize),
          options: [14, 16, 18, 20].map { ($0, "\($0) pt") }, t: t)
      }
    case .readingWidth:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.readingWidth),
          options: [(640, "Narrow · 640 pt"), (780, "Balanced · 780 pt"), (960, "Wide · 960 pt")],
          t: t)
      }
    case .spelling: toggle(item, \.spellCheck)
    case .quotes: toggle(item, \.smartQuotes)
    case .dashes: toggle(item, \.smartDashes)
    case .links: toggle(item, \.automaticLinks)
    case .words: toggle(item, \.wordCount)
    case .assistance: row(item) { ModeSwitch(studio: studio) }
    case .connection:
      VStack(alignment: .leading, spacing: 16) {
        Text(item.title).font(.studio(.control))
        AssistantConnection(studio: studio, advanced: true)
      }.padding(.vertical, 20)
        .overlay(alignment: .bottom) { t.hairline.frame(height: 1) }
    case .sendKey:
      row(item) {
        PreferenceMenu(
          title: item.title, value: preference(\.sendShortcut),
          options: [(.enter, "Return ↵"), (.commandEnter, "Command–Return ⌘↵")], t: t)
      }
    case .identity: WorldIdentitySettings(studio: studio).id(studio.worldID)
    case .cover:
      row(item) {
        HStack(spacing: 8) {
          WorldBadge(studio: studio, radius: 8).frame(width: 38, height: 38)
          Button("Choose…") { studio.chooseWorldCover() }.buttonStyle(QuietButton(t: t))
          if studio.worldCover != nil {
            IconButton(icon: "xmark", label: "Remove world cover", t: t) {
              studio.removeWorldCover()
            }
          }
        }
      }
    case .category: WorldCategorySettings(studio: studio).id(studio.worldID)
    case .chatMode:
      row(item) {
        PreferenceMenu(
          title: item.title,
          value: Binding(
            get: { studio.worldDefaults.chatMode },
            set: { value in
              studio.updateWorldDefaults { $0.chatMode = value }
            }), options: Vocabulary.modes.map { ($0.name, $0.name) }, t: t)
      }
    case .importLore: action(item, "Choose files…") { studio.importDocuments() }
    case .importWorld: action(item, "Open file…") { studio.openPortableWorld() }
    case .portable: action(item, "Export world…") { studio.savePortableWorld() }
    case .markdown: action(item, "Export Markdown…") { studio.exportMarkdown() }
    case .json: action(item, "Export JSON…") { studio.exportWorld() }
    case .images: action(item, "Export images…") { studio.exportWorldImages() }
    case .sample:
      action(item, "Open Aster") {
        studio.loadSample()
        studio.navigate(.worlds)
      }
    }
  }
  private func action(_ item: SettingsItem, _ title: String, perform: @escaping () -> Void)
    -> some View
  {
    row(item) { Button(title, action: perform).buttonStyle(QuietButton(t: t)) }
  }
  private var writingPreview: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Writing preview").font(.studio(size: 11.5, weight: .medium)).foregroundStyle(t.muted)
      Text("Every world begins with a thought.")
        .font(.studio(size: CGFloat(studio.preferences.bodySize))).lineSpacing(6)
      Text(
        "Choose a comfortable size. Your existing titles, emphasis and rich formatting stay intact."
      )
      .font(.studio(size: 13)).foregroundStyle(t.secondary).lineSpacing(3)
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
  }
}

/// Both onboarding and Settings use this connection control; selection does not start a process.
struct AssistantConnection: View {
  @ObservedObject var studio: Studio
  var advanced = false
  private var t: Theme { studio.t }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Provider").font(.studio(.control))
          Text("Codex recommended").font(.studio(.caption)).foregroundStyle(t.secondary)
        }
        Spacer()
        PreferenceMenu(
          title: "Assistant provider",
          value: Binding(get: { studio.provider }, set: studio.setProvider),
          options: ProviderKind.allCases.map { ($0, $0.title) }, t: t)
      }
      HStack(alignment: .center, spacing: 12) {
        Text(studio.providerStatus?.detail ?? "Check sign-in before your first conversation.")
          .font(.studio(size: 12.5)).foregroundStyle(t.secondary)
          .fixedSize(horizontal: false, vertical: true).frame(
            maxWidth: .infinity, alignment: .leading)
        Button(studio.checkingProvider ? "Checking…" : "Check sign-in") { studio.checkProvider() }
          .buttonStyle(QuietButton(t: t)).disabled(studio.checkingProvider)
          .help("Checks subscription status. No model message is sent.")
      }
      if advanced {
        AssistantAdvancedSettings(studio: studio).id(studio.provider)
      } else {
        Text("Optional. Every manual tool works without an assistant.")
          .font(.studio(.caption)).foregroundStyle(t.muted)
      }
    }
  }
}

private struct AssistantAdvancedSettings: View {
  @ObservedObject var studio: Studio
  @State private var model: String
  init(studio: Studio) {
    self.studio = studio
    _model = State(initialValue: studio.harnessModels[studio.provider] ?? "")
  }
  var body: some View {
    DisclosureGroup("Model & connection details", isExpanded: $studio.assistantSettingsExpanded) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .bottom, spacing: 8) {
          FormField(
            label: "Model", placeholder: "Use the subscription default", text: $model, t: studio.t)
          Button("Save") { studio.setHarnessModel(model, for: studio.provider) }
            .buttonStyle(QuietButton(t: studio.t))
            .disabled(
              model.trimmingCharacters(in: .whitespacesAndNewlines)
                == (studio.harnessModels[studio.provider] ?? ""))
        }
        Text(
          "Sign in through the installed \(studio.provider.title) app on this Mac. Synthesis never stores your credentials. If it is not installed, install it and sign in there first."
        )
        Text(
          "Sending a message shares selected world context with your chosen provider. The subscription harness runs in an empty folder without project access or tools. Manual mode blocks generation."
        )
        Text(
          "Image generation is not available in this build. When connected, requested images will use your subscription allowance. Nothing is generated automatically."
        )
      }.font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
        .fixedSize(horizontal: false, vertical: true).padding(.top, 12)
    }.font(.studio(.label)).tint(studio.t.secondary)
  }
}

private struct WorldIdentitySettings: View {
  @ObservedObject var studio: Studio
  @State private var name: String
  @State private var description: String
  private let worldID: String
  init(studio: Studio) {
    self.studio = studio
    worldID = studio.worldID
    _name = State(initialValue: studio.world?.name ?? "")
    _description = State(initialValue: studio.world?.description ?? "")
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      FormField(label: "World name", placeholder: "World name", text: $name, t: studio.t)
      FormTextArea(
        label: "Description", placeholder: "A few words about this universe…",
        text: $description, t: studio.t, height: 100)
      HStack {
        Text("\(description.count) / 4,000").font(.studio(size: 11.5))
          .foregroundStyle(description.count > 4000 ? studio.t.danger : studio.t.muted)
        Spacer()
        Button("Save changes") {
          studio.perform {
            guard studio.worldID == worldID else { throw SynthesisError.notFound }
            try studio.store.updateWorldDetails(
              worldID: worldID, name: name, description: description)
            try studio.reload()
            name = studio.world?.name ?? name
            description = studio.world?.description ?? description
            studio.show("World details saved")
          }
        }.buttonStyle(QuietButton(t: studio.t))
          .disabled(
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description.count > 4000
              || (name == studio.world?.name && description == studio.world?.description))
      }
    }.padding(.vertical, 16)
      .overlay(alignment: .bottom) { studio.t.hairline.frame(height: 1) }
  }
}

private struct WorldCategorySettings: View {
  @ObservedObject var studio: Studio
  @State private var category: String
  init(studio: Studio) {
    self.studio = studio
    _category = State(initialValue: studio.worldDefaults.entityCategory)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(SettingsItem.category.title).font(.studio(.control))
      Text(SettingsItem.category.detail).font(.studio(size: 12.5)).foregroundStyle(
        studio.t.secondary)
      HStack(spacing: 8) {
        FormField(placeholder: "No default — choose when creating", text: $category, t: studio.t)
          .accessibilityLabel("Default entity type")
        Button("Save") {
          studio.updateWorldDefaults { $0.entityCategory = category }
          category = studio.worldDefaults.entityCategory
        }
        .buttonStyle(QuietButton(t: studio.t))
        .disabled(category == studio.worldDefaults.entityCategory || category.count > 80)
      }
      FlowLayout(spacing: 6) {
        ForEach(Vocabulary.categories, id: \.self) { title in
          FilterChip(title: title, selected: category == title, t: studio.t) { category = title }
        }
      }
    }.padding(.vertical, 16)
      .overlay(alignment: .bottom) { studio.t.hairline.frame(height: 1) }
  }
}
