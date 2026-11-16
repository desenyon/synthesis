import AppKit
import SwiftUI

/// Optional illustrations, generated with GPT Image. Installing artwork is an explicit action;
/// neither a record nor a canonical fact is created by selecting an image.
enum StudioArtwork: String, CaseIterable, Identifiable {
  case atlas = "drowned-atlas-gpt"
  case cartographer = "cartographer-gpt"
  var id: String { rawValue }
  var title: String { self == .atlas ? "The drowned coast" : "The cartographer" }
  var subtitle: String { self == .atlas ? "Atlas illustration" : "Character illustration" }
  var data: Data? {
    let path = "Assets/\(rawValue).jpg"
    let installed = Bundle.main.resourceURL?.appendingPathComponent(path)
    let source = Bundle.module.resourceURL?.appendingPathComponent(path)
    for url in [installed, source].compactMap({ $0 }) {
      if let data = try? Data(contentsOf: url) { return data }
    }
    return nil
  }
}

struct ArtworkPicker: View {
  let t: Theme
  var mapOnly = false
  var select: (Data) -> Void
  var close: () -> Void
  var body: some View {
    SheetScaffold(
      title: "Illustration library",
      subtitle:
        "GPT-generated artwork. Choose an image for this world; it does not establish canon.",
      t: t, width: 520, close: close
    ) {
      HStack(alignment: .top, spacing: 12) {
        ForEach(mapOnly ? [StudioArtwork.atlas] : StudioArtwork.allCases) { art in
          if let data = art.data, let image = NSImage(data: data) {
            Button {
              select(data)
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                Image(nsImage: image).resizable().scaledToFill()
                  .frame(width: mapOnly ? 420 : 204, height: mapOnly ? 230 : 150)
                  .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                Text(art.title).font(.studio(size: 15, weight: .medium))
                Text(art.subtitle).font(.studio(size: 12)).foregroundStyle(t.secondary)
              }.padding(8).background(t.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.hairline, lineWidth: 1))
            }.buttonStyle(.plain).help("Use \(art.title)")
          }
        }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: t))
    }
  }
}
