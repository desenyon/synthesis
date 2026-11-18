import AppKit
import SwiftUI
import SynthesisCore

/// Optional entry points for an unwritten entity. These prompts are interface text, never lore.
struct EntityProfileStart: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var write: (String?) -> Void
  @State private var relationships: [RecordRelationship] = []
  @State private var events: [WorldEvent] = []
  @Environment(\.studioDensity) private var density
  private var prompts: [String] {
    switch Vocabulary.categoryKey(record.category) {
    case "characters": ["What do they want?", "What changed them?", "What do they keep secret?"]
    case "systems": ["What brings them together?", "Who holds influence?", "What divides them?"]
    case "places": ["What makes this place distinct?", "Who calls it home?", "What happened here?"]
    case "power systems": ["What makes it possible?", "What does it cost?", "What is impossible?"]
    case "cosmology":
      ["What exists beyond this world?", "What holds it together?", "What remains unknown?"]
    default: ["What makes it distinct?", "Where did it begin?", "What remains unknown?"]
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: density.contentGap) {
        EntityArtworkControl(studio: studio, record: record)
        VStack(alignment: .leading, spacing: Space.md) {
          Text("Start with what you know").font(.studio(.section)).foregroundStyle(studio.t.text)
          Text("A few words are enough. Add detail and connections whenever you need them.")
            .font(.studio(.control)).foregroundStyle(studio.t.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Button("Start writing") { write(nil) }
            .buttonStyle(QuietButton(t: studio.t, primary: true))
          VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(prompts, id: \.self) { prompt in
              Button {
                write(prompt)
              } label: {
                HStack(spacing: Space.sm) {
                  Text(prompt).font(.studio(.label)).multilineTextAlignment(.leading)
                  StudioIcon("arrow.right", size: 12)
                }.foregroundStyle(studio.t.secondary).padding(.vertical, Space.xs)
                  .contentShape(Rectangle())
              }.buttonStyle(.plain).help("Use this optional writing prompt")
            }
          }
        }
        Rectangle().fill(studio.t.hairline).frame(height: 1)
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 220), spacing: Space.xl)], alignment: .leading,
          spacing: Space.xl
        ) {
          VStack(alignment: .leading, spacing: Space.md) {
            Text("Relationships").font(.studio(.cardTitle))
            if relationships.isEmpty {
              Text("Connect this entity to the people, places and ideas around it.")
                .font(.studio(.label)).foregroundStyle(studio.t.secondary)
            } else {
              ForEach(relationships.prefix(3)) { relation in
                Button {
                  studio.openRecord(relation.counterpart)
                } label: {
                  VStack(alignment: .leading, spacing: Space.xs) {
                    Text(relation.counterpart.title).font(.studio(.control)).lineLimit(1)
                    Text(relation.detail).font(.studio(.caption)).foregroundStyle(
                      studio.t.secondary
                    ).lineLimit(1)
                  }
                }.buttonStyle(.plain).help("Open \(relation.counterpart.title)")
              }
            }
            Button("Open relationship map") { studio.showRelationships(for: record) }
              .buttonStyle(QuietButton(t: studio.t))
          }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          VStack(alignment: .leading, spacing: Space.md) {
            Text("History").font(.studio(.cardTitle))
            if events.isEmpty {
              Text("Begin a personal chronology. Dates can stay unknown.")
                .font(.studio(.label)).foregroundStyle(studio.t.secondary)
            } else {
              ForEach(events.prefix(3)) { event in
                VStack(alignment: .leading, spacing: Space.xs) {
                  Text(event.title).font(.studio(.control)).lineLimit(2)
                  Text(event.dateLabel == "unknown" ? "Date unknown" : event.dateLabel)
                    .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
                }
              }
            }
            Button("Add a moment") { studio.beginEvent(for: record) }
              .buttonStyle(QuietButton(t: studio.t))
            if !events.isEmpty {
              Button("Open timeline") { studio.navigate(.timeline) }
                .buttonStyle(QuietButton(t: studio.t, role: .ghost))
            }
          }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }.padding(.vertical, density.contentGap).padding(.bottom, Space.xl)
    }.onAppear(perform: refresh)
      .onChange(of: studio.worldRevision) { _, _ in refresh() }
  }
  private func refresh() {
    studio.perform {
      relationships = try studio.recordRelationships(for: record)
      events = try studio.store.events(worldID: record.worldID).filter { $0.sourceID == record.id }
    }
  }
}

/// The same artwork control stays available after writing begins.
struct EntityArtworkControl: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  var compact = false
  @State private var artwork: RecordArtwork?
  @State private var library = false
  private var portrait: Bool { Vocabulary.categoryKey(record.category) == "characters" }
  var body: some View {
    HStack(alignment: .center, spacing: Space.lg) {
      if let artwork, let image = ImageCache.image(base64: artwork.image) {
        Image(nsImage: image).resizable().scaledToFill()
          .frame(width: compact ? 72 : 112, height: compact ? 72 : 132).clipped()
          .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
          .accessibilityLabel("Artwork for \(record.title)")
          .workspaceReferenceDraggable(
            WorldReference(worldID: record.worldID, kind: .artwork, id: artwork.id),
            title: "Artwork · \(record.title)", icon: "photo", studio: studio)
      }
      VStack(alignment: .leading, spacing: Space.sm) {
        if !compact || artwork != nil {
          Text(portrait ? "Portrait" : "Visual reference").font(.studio(.label))
          Text(
            artwork == nil
              ? "Optional. Choose your own image."
              : "\(artwork?.origin == "ai-generated" ? "AI-generated" : "Imported") visual reference"
          )
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
        }
        HStack(spacing: Space.sm) {
          Button {
            choose()
          } label: {
            StudioLabel(
              artwork == nil ? (portrait ? "Add portrait" : "Add artwork") : "Replace",
              icon: "photo")
          }.buttonStyle(QuietButton(t: studio.t))
          IconMenu(icon: "ellipsis", label: "Artwork options", t: studio.t) {
            Button("Illustration library…") { library = true }
            if artwork != nil { Button("Remove artwork") { remove() } }
          }
        }
      }
      Spacer(minLength: 0)
    }.onAppear(perform: refresh)
      .onChange(of: studio.worldRevision) { _, _ in refresh() }
      .studioSheet(isPresented: $library) {
        ArtworkPicker(
          t: studio.t, studio: studio,
          select: { data in
            save(data, origin: "ai-generated")
            library = false
          }, close: { library = false })
      }
  }
  private func refresh() {
    studio.perform {
      artwork = try studio.store.recordArtwork(worldID: record.worldID, recordID: record.id)
    }
  }
  private func choose() {
    studio.perform {
      if let base64 = try pickImage(), let data = Data(base64Encoded: base64) {
        save(data, origin: "imported")
      }
    }
  }
  private func save(_ data: Data, origin: String) {
    let old = artwork?.id
    studio.perform {
      let value = try studio.store.saveRecordArtwork(
        worldID: record.worldID, recordID: record.id, data: data, origin: origin, expectedID: old)
      try studio.reload()
      artwork = value
      studio.show("Artwork saved", icon: "photo", actionTitle: "Undo") {
        restore(old, expected: value.id)
      }
    }
  }
  private func remove() {
    let old = artwork?.id
    studio.perform {
      try studio.store.restoreRecordArtwork(
        worldID: record.worldID, recordID: record.id, id: nil, expectedID: old)
      try studio.reload()
      artwork = nil
      studio.show("Artwork removed", actionTitle: "Undo") { restore(old, expected: nil) }
    }
  }
  private func restore(_ id: String?, expected: String?) {
    studio.perform {
      try studio.store.restoreRecordArtwork(
        worldID: record.worldID, recordID: record.id, id: id, expectedID: expected)
      try studio.reload()
      refresh()
    }
  }
}
