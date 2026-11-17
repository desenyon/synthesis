import AppKit
import ImageIO
import SwiftUI
import SynthesisCore

/// Detail changes never change the graph's world positions. The same bounds drive
/// the visible card, connection ports, obstacle routing and viewport culling.
enum GraphDetail: Equatable {
  case overview, summary, detail

  init(scale: Double) {
    self = scale < 0.55 ? .overview : scale < 0.95 ? .summary : .detail
  }
  var cardSize: CGSize {
    CGSize(
      width: GraphLayout.cardSize.width,
      height: self == .overview ? 64 : self == .summary ? 148 : 208)
  }
  func showsRelationship(hovered: Bool) -> Bool {
    self == .detail || hovered
  }
}

/// Bounded decoded thumbnails, keyed by immutable artwork revision. Pan/zoom never
/// decode full resolution artwork. Offscreen nodes do not instantiate this view.
@MainActor enum GraphThumbnail {
  private static let cache: NSCache<NSString, NSImage> = {
    let result = NSCache<NSString, NSImage>()
    result.countLimit = 100
    result.totalCostLimit = 32 * 1024 * 1024
    return result
  }()
  static func cached(_ id: String) -> NSImage? { cache.object(forKey: id as NSString) }
  static func remember(_ image: NSImage, id: String) {
    cache.setObject(
      image, forKey: id as NSString, cost: Int(image.size.width * image.size.height * 4))
  }
  nonisolated static func decode(_ data: Data) -> NSImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source, 0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 192,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary)
    else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
  }
}

struct GraphArtwork: View {
  let store: WorkspaceStore
  let worldID: String
  let recordID: String
  let revision: String
  @State private var image: NSImage?

  var body: some View {
    Group {
      if let displayed = image ?? GraphThumbnail.cached(revision) {
        Image(nsImage: displayed).resizable().scaledToFill()
      } else {
        Color.clear
      }
    }
    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityHidden(true)
    .task(id: revision) {
      image = GraphThumbnail.cached(revision)
      guard image == nil,
        let artwork = try? store.recordArtwork(worldID: worldID, recordID: recordID),
        artwork.id == revision, let data = Data(base64Encoded: artwork.image)
      else { return }
      let worker = Task.detached(priority: .utility) { GraphThumbnail.decode(data) }
      let decoded = await withTaskCancellationHandler {
        await worker.value
      } onCancel: {
        worker.cancel()
      }
      guard !Task.isCancelled, let decoded else { return }
      GraphThumbnail.remember(decoded, id: revision)
      image = decoded
    }
  }
}
