import AppKit
import SwiftUI
import SynthesisCore

extension Studio {
  public func savePortableWorld() {
    guard flushEditor() else { return }
    let requestedWorld = worldID
    Task { @MainActor in
      guard await flushCanvas(), worldID == requestedWorld else { return }
      let panel = NSSavePanel()
      panel.title = "Save a portable world"
      panel.nameFieldStringValue = "\(world?.name ?? "World").synthesis"
      panel.message =
        "Includes lore, conversations, boards, images and history. Your working world stays in Synthesis."
      guard panel.runModal() == .OK, let url = panel.url else { return }
      perform {
        try store.exportWorldArchive(worldID: worldID).write(to: url, options: .atomic)
        try store.setPreference("world-file:\(worldID)", value: url.path)
        show("Saved \(url.lastPathComponent)", icon: "square.and.arrow.up")
      }
    }
  }
  public func openPortableWorld() {
    guard flushEditor() else { return }
    let panel = NSOpenPanel()
    panel.title = "Open a Synthesis world"
    panel.message = "Opens an independent copy. Existing worlds are preserved."
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    perform {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= 200_000_000 else {
        throw SynthesisError.invalid("This world file exceeds 200 MB.")
      }
      let imported = try store.importWorldArchive(Data(contentsOf: url))
      try reload()
      switchWorld(imported.id)
      navigate(mode == .manual ? .library : .chat)
      show("Opened \(imported.name)")
    }
  }
}

struct WorldsScreen: View {
  @ObservedObject var studio: Studio
  @State private var query = ""
  private var worlds: [World] {
    studio.worlds.filter {
      query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
        || $0.description.localizedCaseInsensitiveContains(query)
    }
  }
  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        Text("Your worlds").font(.studio(size: 15, weight: .semibold))
      } trailing: {
        Button("Open file…") { studio.openPortableWorld() }.buttonStyle(QuietButton(t: studio.t))
        Button("New world") { studio.sheet = .world }.buttonStyle(
          QuietButton(t: studio.t, primary: true))
      }
      ScrollView {
        ContentColumn {
          VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 8) {
              Text("A place for every universe.").font(.studio(size: 30, weight: .semibold))
                .tracking(
                  -0.8)
              Text("Open a world, pick up a thought, or take your work with you.")
                .font(.studio(size: 15)).foregroundStyle(studio.t.secondary)
            }
            FormField(placeholder: "Find a world…", text: $query, t: studio.t)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
              ForEach(worlds) { world in
                VStack(alignment: .leading, spacing: 16) {
                  HStack {
                    StudioIcon("globe", size: 26).foregroundStyle(studio.t.accent)
                    Spacer()
                    if world.demo {
                      Text("Sample").font(.studio(size: 12)).foregroundStyle(studio.t.muted)
                    }
                    PlainMenu {
                      Button("Save world file…") {
                        studio.switchWorld(world.id)
                        studio.savePortableWorld()
                      }
                      Button("Export Markdown…") {
                        studio.switchWorld(world.id)
                        studio.exportMarkdown()
                      }
                      Button("Export JSON…") {
                        studio.switchWorld(world.id)
                        studio.exportWorld()
                      }
                    } label: {
                      StudioIcon("ellipsis").frame(width: 28, height: 28)
                    }
                  }
                  Button {
                    studio.switchWorld(world.id)
                    studio.navigate(studio.mode == .manual ? .library : .chat)
                  } label: {
                    VStack(alignment: .leading, spacing: 8) {
                      Text(world.name).font(.studio(size: 20, weight: .semibold)).lineLimit(2)
                      Text(
                        world.description.isEmpty
                          ? "An open world of possibilities." : world.description
                      )
                      .font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineLimit(3)
                      HStack {
                        Text(world.id == studio.worldID ? "Continue creating" : "Open world")
                        Spacer()
                        StudioIcon("arrow.up.forward")
                      }.font(.studio(size: 13, weight: .medium)).foregroundStyle(studio.t.accent)
                        .padding(.top, 12)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                  }.buttonStyle(.plain)
                }.padding(22).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 16))
                  .overlay(RoundedRectangle(cornerRadius: 16).stroke(studio.t.hairline))
              }
            }
            if worlds.isEmpty {
              Text("No worlds match your search.").foregroundStyle(studio.t.secondary)
            }
          }.padding(.vertical, 28)
        }
      }
    }
  }
}

extension Studio {
  public func exportWorldImages() {
    guard flushEditor() else { return }
    let requestedWorld = worldID
    Task { @MainActor in
      guard await flushCanvas(), worldID == requestedWorld else { return }
      perform {
        var images: [Data] = []
        var seen = Set<Data>()
        func collect(_ value: Any, key: String = "", depth: Int = 0) {
          guard depth < 64 else { return }
          if let object = value as? [String: Any] {
            for (key, child) in object { collect(child, key: key, depth: depth + 1) }
          } else if let array = value as? [Any] {
            for child in array { collect(child, depth: depth + 1) }
          } else if let raw = value as? String {
            let base64: String
            if raw.hasPrefix("data:image/"), let comma = raw.firstIndex(of: ",") {
              base64 = String(raw[raw.index(after: comma)...])
            } else if key == "image" || key == "world-cover" {
              base64 = raw
            } else {
              return
            }
            guard let data = Data(base64Encoded: base64), data.count <= 20_000_000,
              let bitmap = NSBitmapImageRep(data: data),
              let png = bitmap.representation(using: .png, properties: [:]),
              seen.insert(png).inserted
            else { return }
            images.append(png)
          }
        }
        if let cover = try store.preference("world-cover:\(worldID)") {
          collect(cover, key: "world-cover")
        }
        for kind in ["canvas", "atlas"] {
          for board in try store.boards(worldID: worldID, kind: kind) {
            if let data = board.content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
            {
              collect(object)
            }
          }
        }
        guard !images.isEmpty else {
          show("This world has no saved images to export.")
          return
        }
        let panel = NSOpenPanel()
        panel.title = "Export world images"
        panel.message = "Creates a new folder with \(images.count) PNG images."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        let folder = directory.appendingPathComponent(
          "Synthesis Images \(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        do {
          for (index, image) in images.enumerated() {
            try image.write(
              to: folder.appendingPathComponent(String(format: "Image-%03d.png", index + 1)),
              options: .atomic)
          }
        } catch {
          // Only this newly created export folder is removed on a partial export.
          try? FileManager.default.removeItem(at: folder)
          throw error
        }
        show("Exported \(images.count) images", icon: "photo", actionTitle: "Show") {
          NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
      }
    }
  }
}
