import SwiftUI
import SynthesisCore

struct RecordConnections: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var done: (LoreRecord) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var outgoing: [LoreRecord] = []
  @State private var incoming: [LoreRecord] = []
  @State private var tags = ""
  @State private var aliases = ""
  @State private var target = ""
  @State private var initialTags = ""
  @State private var initialAliases = ""
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("The threads around this idea.").font(.system(size: 27, design: .serif))
      Text(record.title).font(.system(size: 13)).foregroundStyle(studio.t.secondary)
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.system(size: 12, weight: .medium))
            TextField("ocean, memory, mystery", text: $tags).textFieldStyle(.roundedBorder)
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Aliases").font(.system(size: 12, weight: .medium))
            TextField("Alternative names, separated by commas", text: $aliases).textFieldStyle(
              .roundedBorder)
          }
          Divider()
          Text("Linked records").font(.system(size: 14, weight: .medium))
          if outgoing.isEmpty {
            Text("Connect this idea to a character, place, or another page.").font(
              .system(size: 12)
            ).foregroundStyle(studio.t.secondary)
          }
          ForEach(outgoing) { linked in sourceButton(linked) }
          HStack {
            Picker("Link", selection: $target) {
              Text("Choose a record").tag("")
              ForEach(studio.records.filter { $0.id != record.id }) { Text($0.title).tag($0.id) }
            }.labelsHidden()
            Button("Link record") {
              studio.perform {
                try studio.store.linkRecord(
                  worldID: studio.worldID, source: record.id, target: target)
                loadLinks()
                target = ""
              }
            }.disabled(target.isEmpty)
          }
          Divider()
          Text("Referenced by").font(.system(size: 14, weight: .medium))
          if incoming.isEmpty {
            Text("No incoming links yet.").font(.system(size: 12)).foregroundStyle(
              studio.t.secondary)
          }
          ForEach(incoming) { linked in sourceButton(linked) }
        }
      }
      HStack {
        Text("Links are references, not canonical claims.").font(.system(size: 11)).foregroundStyle(
          studio.t.secondary)
        Spacer()
        Button("Done") { finish() }.buttonStyle(QuietButton(t: studio.t, primary: true))
      }
    }.padding(28).frame(width: 480, height: 540).onAppear {
      tags = (record.tags ?? []).joined(separator: ", ")
      aliases = (record.aliases ?? []).joined(separator: ", ")
      initialTags = tags
      initialAliases = aliases
      loadLinks()
    }
  }
  private func sourceButton(_ linked: LoreRecord) -> some View {
    Button {
      guard let updated = saveMetadata() else { return }
      done(updated)
      dismiss()
      studio.openRecord(linked)
    } label: {
      Label(linked.title + " ↗", systemImage: "link")
    }.buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(studio.t.accent)
  }
  private func loadLinks() {
    studio.perform {
      outgoing = try studio.store.linkedRecords(worldID: studio.worldID, id: record.id)
      incoming = try studio.store.linkedRecords(
        worldID: studio.worldID, id: record.id, incoming: true)
    }
  }
  private func values(_ text: String) -> [String] {
    Array(
      Set(
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter
        { !$0.isEmpty })
    ).sorted()
  }
  private func saveMetadata() -> LoreRecord? {
    do {
      if tags == initialTags && aliases == initialAliases { return record }
      let updated = try studio.store.saveMetadata(
        worldID: studio.worldID, id: record.id, version: record.version, tags: values(tags),
        aliases: values(aliases))
      try studio.reload()
      return updated
    } catch {
      studio.error = error.localizedDescription
      return nil
    }
  }
  private func finish() { if let updated = saveMetadata() { done(updated) } }
}
