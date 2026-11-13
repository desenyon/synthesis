import SwiftUI
import SynthesisCore

struct StudioSheet: View {
  @ObservedObject var studio: Studio
  let sheet: Studio.Sheet
  @State private var name = ""
  @State private var kind = "lore"
  @State private var key = ""
  @State private var model = ""
  @State private var query = ""
  @State private var saved = false
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack {
        Text(title).font(.system(size: 24, weight: .medium, design: .serif))
        Spacer()
        IconButton(icon: "xmark", label: "Close", t: studio.t) { studio.sheet = nil }
      }
      switch sheet {
      case .world:
        Text("A new world begins with a name. You can leave everything else open.").font(
          .system(size: 14)
        ).foregroundStyle(studio.t.secondary)
        TextField("World name", text: $name).textFieldStyle(.roundedBorder).onSubmit {
          studio.createWorld(name)
        }
        Button("Create world") { studio.createWorld(name) }.buttonStyle(
          QuietButton(t: studio.t, primary: true)
        ).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      case .document:
        TextField("Give it a name", text: $name).textFieldStyle(.roundedBorder).onSubmit {
          studio.createRecord(title: name, kind: kind)
        }
        Picker("Type", selection: $kind) {
          Text("Document").tag("lore")
          Text("Entity").tag("entity")
          Text("Loose idea").tag("capture")
        }.pickerStyle(.segmented)
        Button("Create draft") { studio.createRecord(title: name, kind: kind) }.buttonStyle(
          QuietButton(t: studio.t, primary: true)
        ).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      case .rename:
        TextField("Conversation name", text: $name).textFieldStyle(.roundedBorder)
        Button("Rename") {
          studio.perform {
            if let id = studio.conversationID {
              try studio.store.renameConversation(worldID: studio.worldID, id: id, title: name)
              try studio.reload()
            }
            studio.sheet = nil
          }
        }.buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(
          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      case .search:
        TextField("Find a page, entity, or conversation…", text: $query).textFieldStyle(
          .roundedBorder)
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(searchRecords) { record in
              Button {
                studio.sheet = nil
                studio.openRecord(record)
              } label: {
                Label(record.title, systemImage: record.kind == "entity" ? "person" : "doc.text")
                  .font(.system(size: 14)).padding(10).frame(
                    maxWidth: .infinity, alignment: .leading)
              }.buttonStyle(.plain)
            }
            ForEach(
              studio.conversations.filter {
                query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
              }
            ) { chat in
              Button {
                studio.sheet = nil
                studio.openChat(chat)
              } label: {
                Label(chat.title, systemImage: "bubble.left").font(.system(size: 14)).padding(10)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }.buttonStyle(.plain)
            }
            if searchRecords.isEmpty && studio.conversations.isEmpty {
              Text("Nothing here yet. Capture an idea to get started.").foregroundStyle(
                studio.t.secondary
              ).font(.system(size: 13)).padding(.vertical, 20)
            }
          }
        }.frame(minHeight: 200, maxHeight: 400)
      case .settings: settings
      }
    }.padding(28).frame(minWidth: 340, idealWidth: 500, maxWidth: 540).background(
      studio.t.background
    ).foregroundStyle(studio.t.text).onAppear {
      model = studio.modelName
      if sheet == .rename {
        name = studio.conversations.first { $0.id == studio.conversationID }?.title ?? ""
      }
    }
  }
  private var searchRecords: [LoreRecord] {
    if query.isEmpty { return Array(studio.records.prefix(12)) }
    return (try? studio.store.search(worldID: studio.worldID, query: query)) ?? []
  }
  private var title: String {
    switch sheet {
    case .settings: return "Make yourself at home."
    case .world: return "An unwritten world."
    case .document: return "Start with a thought."
    case .rename: return "Name this conversation."
    case .search: return "Find a thread."
    }
  }
  private var settings: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Label("Appearance", systemImage: studio.dark ? "moon" : "sun.max")
        Spacer()
        Button(studio.dark ? "Switch to light" : "Switch to dark") { studio.toggleTheme() }
          .buttonStyle(QuietButton(t: studio.t))
      }.font(.system(size: 13))
      Divider().overlay(studio.t.border)
      Text("Your model connection").font(.system(size: 16, weight: .medium))
      Text(
        "Optional. All manual tools work without a provider. Only sending a message shares your prompt and selected world's context with OpenAI."
      ).font(.system(size: 13)).foregroundStyle(studio.t.secondary).lineSpacing(4)
      VStack(alignment: .leading, spacing: 8) {
        Text("API key · macOS Keychain").font(.system(size: 12))
        SecureField(
          studio.providerConfigured
            ? "Key stored — leave blank to keep it" : "Enter an OpenAI API key", text: $key
        ).textFieldStyle(.roundedBorder)
        Text("Model ID").font(.system(size: 12))
        TextField("A model available to your OpenAI account", text: $model).textFieldStyle(
          .roundedBorder)
      }
      HStack {
        Button("Save connection") {
          studio.perform {
            if !key.isEmpty { try ProviderKeychain.save(key) }
            try studio.store.setPreference(
              "model", value: model.trimmingCharacters(in: .whitespacesAndNewlines))
            studio.modelName = model.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(studio.modelName, forKey: "Synthesis.model")
            studio.providerConfigured = ProviderKeychain.configured && !studio.modelName.isEmpty
            key = ""
            saved = true
          }
        }.buttonStyle(QuietButton(t: studio.t, primary: true))
        if studio.providerConfigured {
          Button("Disconnect") {
            studio.stop()
            studio.perform {
              try ProviderKeychain.remove()
              studio.providerConfigured = false
              saved = false
            }
          }.buttonStyle(.plain).foregroundStyle(studio.t.secondary)
        }
      }
      if saved {
        Text("Saved locally. No request was made.").font(.system(size: 12)).foregroundStyle(
          studio.t.accent)
      }
      Divider().overlay(studio.t.border)
      HStack {
        Button("Export this world…") { studio.exportWorld() }.buttonStyle(QuietButton(t: studio.t))
        Spacer()
        Button("Open sample world") {
          studio.loadSample()
          studio.sheet = nil
        }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(studio.t.accent)
      }
    }
  }
}
