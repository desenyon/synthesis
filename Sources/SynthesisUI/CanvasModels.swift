import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

/// The layout format of the earlier native canvas. It is still used to seed boards (the sample
/// world, "Copy to canvas" from Graph) and to read boards saved before the Excalidraw engine;
/// the canvas converts it on first open. Fields must stay optional or defaulted.
struct CanvasCard: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var text = "An unwritten thought"
  var recordID: String?
  var image: String?
  var x = 0.0
  var y = 0.0
  var width = 230.0
  var height = 160.0
  var group: String?
}
struct CanvasEdge: Codable, Equatable {
  var label: String?
  var source: String
  var target: String
}
struct CanvasDocument: Codable, Equatable {
  var viewport: BoardViewport?
  var cards: [CanvasCard] = []
  var edges: [CanvasEdge] = []
}
struct BoardViewport: Codable, Equatable {
  var x = 0.0
  var y = 0.0
  var zoom = 1.0
}
struct MapMarker: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var recordID: String
  var x: Double
  var y: Double
}
/// An area drawn on a map and linked to a record, usually a place. Points are fractions of the
/// image width and height, so the region stays put when the image is shown at any size.
struct MapRegion: Identifiable, Codable, Equatable {
  var id = UUID().uuidString
  var recordID: String
  var points: [[Double]]
}
struct AtlasDocument: Codable, Equatable {
  var placeID: String?
  var parentMapID: String?
  var image: String?
  var markers: [MapMarker] = []
  var regions: [MapRegion] = []
  init(
    placeID: String? = nil, parentMapID: String? = nil, image: String? = nil,
    markers: [MapMarker] = [], regions: [MapRegion] = []
  ) {
    self.placeID = placeID
    self.parentMapID = parentMapID
    self.image = image
    self.markers = markers
    self.regions = regions
  }
  /// Maps saved before regions existed have no `regions` key.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    placeID = try container.decodeIfPresent(String.self, forKey: .placeID)
    parentMapID = try container.decodeIfPresent(String.self, forKey: .parentMapID)
    image = try container.decodeIfPresent(String.self, forKey: .image)
    markers = try container.decodeIfPresent([MapMarker].self, forKey: .markers) ?? []
    regions = try container.decodeIfPresent([MapRegion].self, forKey: .regions) ?? []
  }
}

/// A relationship or board link resolved to the cards it joins.
struct DisplayEdge: Identifiable, Equatable {
  var id: String
  var source: String
  var target: String
  var label: String
  var localIndex: Int?
}

/// Lane offsets so several connectors between one pair of cards do not overlap.
func edgeLanes(_ edges: [DisplayEdge], spacing: Double = 26) -> [String: Double] {
  var groups: [Set<String>: [String]] = [:]
  for edge in edges { groups[[edge.source, edge.target], default: []].append(edge.id) }
  var lanes: [String: Double] = [:]
  for ids in groups.values {
    for (index, id) in ids.enumerated() {
      lanes[id] = (Double(index) - Double(ids.count - 1) / 2) * spacing
    }
  }
  return lanes
}

func pickImage(limit: Int = 6_000_000) throws -> String? {
  let panel = NSOpenPanel()
  panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
  panel.allowsMultipleSelection = false
  guard panel.runModal() == .OK, let url = panel.url else { return nil }
  let data = try Data(contentsOf: url)
  return try browserImageBase64(data, limit: limit)
}

/// The web engine accepts PNG/JPEG, while the native picker also accepts HEIC/TIFF.
/// Convert at the boundary instead of labelling arbitrary image bytes as PNG.
func browserImageBase64(_ data: Data, limit: Int) throws -> String {
  guard data.count <= limit, let bitmap = NSBitmapImageRep(data: data) else {
    throw SynthesisError.invalid("Choose a readable image under \(limit / 1_000_000) MB.")
  }
  guard bitmap.pixelsWide > 0, bitmap.pixelsHigh > 0,
    bitmap.pixelsWide <= 8192, bitmap.pixelsHigh <= 8192
  else {
    throw SynthesisError.invalid("Choose an image no larger than 8192 pixels on either side.")
  }
  let png = data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10])
  let jpeg = data.starts(with: [255, 216, 255])
  let output = (png || jpeg) ? data : bitmap.representation(using: .png, properties: [:])
  guard let output, output.count <= limit else {
    throw SynthesisError.invalid(
      "This image is too large after conversion. Export a smaller PNG or JPEG.")
  }
  return output.base64EncodedString()
}
