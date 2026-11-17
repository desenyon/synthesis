import AppKit
import SwiftUI

/// Bundled sample illustrations (AI-generated). Installing artwork is an explicit action;
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
  /// When set, the picker also offers an explicit Codex image request.
  var studio: Studio?
  var select: (Data) -> Void
  var close: () -> Void
  var body: some View {
    SheetScaffold(
      title: "Illustration library",
      subtitle:
        "Bundled sample artwork, AI-generated. Choosing one does not establish canon.",
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
                  .frame(
                    width: mapOnly ? 420 : 204,
                    height: mapOnly ? (studio == nil ? 230 : 140) : (studio == nil ? 150 : 110)
                  )
                  .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                Text(art.title).font(.studio(size: 15, weight: .medium))
                Text(art.subtitle).font(.studio(size: 12)).foregroundStyle(t.secondary)
              }.padding(8).background(t.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.hairline, lineWidth: 1))
            }.buttonStyle(.plain).help("Use \(art.title)")
          }
        }
      }
      if let studio { GenerateImageSection(studio: studio, mapOnly: mapOnly, select: select) }
    } footer: {
      Spacer()
      Button("Cancel") {
        studio?.stopImageGeneration()
        close()
      }.buttonStyle(QuietButton(t: t))
    }
  }
}

/// Describe an image and generate it with the creator's own Codex subscription. The description
/// is the only content sent; world lore is not included.
private struct GenerateImageSection: View {
  @ObservedObject var studio: Studio
  let mapOnly: Bool
  var select: (Data) -> Void
  @State private var description = ""
  var body: some View {
    let t = studio.t
    VStack(alignment: .leading, spacing: 10) {
      Rectangle().fill(t.hairline).frame(height: 1).padding(.vertical, 4)
      Text("Generate with Codex").font(.studio(size: 14, weight: .semibold))
      TextField(
        mapOnly
          ? "A hand-drawn map of a drowned archipelago, seen from above, muted inks"
          : "A cartographer on a cliff at dawn, holding a damp chart",
        text: $description, axis: .vertical
      ).lineLimit(2...4).textFieldStyle(.plain).font(.studio(size: 14)).padding(10)
        .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.border, lineWidth: 1))
        .accessibilityLabel("Image description")
      Text(
        studio.mode == .manual
          ? "Manual is on, so nothing can be sent. Switch to AI Assisted to generate."
          : "Sends only this description to Codex using your ChatGPT subscription allowance. No world lore is included. Codex also keeps its own copy in its generated_images folder."
      ).font(.studio(size: 12)).foregroundStyle(t.muted).fixedSize(
        horizontal: false, vertical: true)
      HStack(spacing: 8) {
        if studio.generatingImage {
          ProgressView().controlSize(.small)
          Text("Generating… this can take a minute").font(.studio(size: 12.5))
            .foregroundStyle(t.secondary)
          Spacer()
          Button("Stop") { studio.stopImageGeneration() }.buttonStyle(QuietButton(t: t))
        } else {
          Spacer()
          Button("Generate image") {
            studio.generateImage(description) { data in select(data) }
          }.buttonStyle(QuietButton(t: t, primary: true))
            .disabled(
              studio.mode == .manual
                || description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }.onAppear {
      if studio.captureHint == "sheet-generate" {
        description = "A hand-drawn map of a drowned archipelago, seen from above, muted inks"
      }
    }
  }
}
