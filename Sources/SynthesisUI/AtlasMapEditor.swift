import SwiftUI
import SynthesisCore

struct AtlasMapEditor: View {
  @ObservedObject var studio: Studio
  let board: Board?
  let maps: [Board]
  var close: (Board?) -> Void
  @State private var name = ""
  @State private var placeID = ""
  @State private var parentID = ""
  @State private var places = false
  @State private var error: String?
  var body: some View {
    SheetScaffold(
      title: board == nil ? "New map" : "Map details",
      subtitle: "Connect a world, region or local place.", t: studio.t, width: 480,
      close: { close(nil) }
    ) {
      FormField(label: "Name", placeholder: "The northern coast", text: $name, t: studio.t)
      VStack(alignment: .leading, spacing: 7) {
        Text("Place record").font(.studio(.captionStrong)).foregroundStyle(
          studio.t.secondary)
        HStack {
          Button {
            places = true
          } label: {
            StudioLabel(
              studio.records.first { $0.id == placeID }?.title ?? "Choose a place…",
              icon: "mappin.and.ellipse"
            )
            .lineLimit(1)
          }.buttonStyle(QuietButton(t: studio.t))
            .popover(isPresented: $places) {
              SearchableRecordPicker(
                records: studio.records.filter { $0.kind == "entity" }, t: studio.t
              ) { record in
                placeID = record.id
                places = false
              }
            }
          if !placeID.isEmpty {
            Button("Clear") { placeID = "" }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
          }
        }
      }
      ChoiceField(
        title: "Inside map", selection: $parentID,
        choices: [("", "No parent map")]
          + maps.filter { $0.id != board?.id }.map { ($0.id, $0.name) }, t: studio.t)
      Text("Maps share linked lore, but each keeps its own image and marker positions.")
        .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
      if let error { Text(error).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
    } footer: {
      Spacer()
      Button("Cancel") { close(nil) }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button(board == nil ? "Create map" : "Save details") { save() }
        .buttonStyle(QuietButton(t: studio.t, primary: true))
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }.onAppear {
      name = board?.name ?? ""
      if let content = board?.content, let links = try? AtlasLinks(content: content) {
        placeID = links.placeID ?? ""
        parentID = links.parentMapID ?? ""
      }
    }
  }
  private func save() {
    do {
      var object: [String: Any] = ["markers": [[String: Any]]()]
      if let board {
        guard
          let decoded = try JSONSerialization.jsonObject(with: Data(board.content.utf8))
            as? [String: Any]
        else {
          throw SynthesisError.invalid("This map cannot be read.")
        }
        object = decoded
      }
      object["placeID"] = placeID.isEmpty ? nil : placeID
      object["parentMapID"] = parentID.isEmpty ? nil : parentID
      let saved = try studio.store.saveAtlasMap(
        worldID: studio.worldID, id: board?.id, name: name,
        content: String(
          decoding: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          as: UTF8.self), expected: board)
      try studio.reload()
      close(saved)
    } catch { self.error = error.localizedDescription }
  }
}
