import AppKit
import Testing

@testable import SynthesisUI

struct GraphDetailTests {
  @Test func semanticBoundsStayInsideLayoutAndConnectionsMeetVisibleCards() {
    let centres = GraphLayout.positions(nodes: ["a", "b"], edges: [("a", "b")], landscape: false)
    for scale in [0.25, 0.54, 0.55, 0.8, 0.95, 1.4] {
      let detail = GraphDetail(scale: scale)
      #expect(detail.cardSize.width <= GraphLayout.cardSize.width)
      #expect(detail.cardSize.height <= GraphLayout.cardSize.height)
      let a = CGPoint(x: centres["a"]!.x * scale, y: centres["a"]!.y * scale)
      let b = CGPoint(x: centres["b"]!.x * scale, y: centres["b"]!.y * scale)
      let route = GraphRoute.between(a, b, scale: scale, lane: 0, cardSize: detail.cardSize)
      #expect(abs(route.start.y - a.y - detail.cardSize.height * scale / 2 - 7) < 0.001)
      #expect(abs(b.y - route.end.y - detail.cardSize.height * scale / 2 - 7) < 0.001)
      #expect(route.start.y < route.end.y)
      #expect(detail.showsRelationship(hovered: true))
      #expect(detail.showsRelationship(hovered: false) == (scale >= 0.95))
    }
  }

  @Test func overviewRoutesStillAvoidVisibleObstacles() {
    let size = GraphDetail.overview.cardSize
    let obstacle = CGRect(x: 370, y: -size.height / 2, width: size.width, height: size.height)
    let route = GraphRoute.between(
      .zero, CGPoint(x: 1000, y: 0), scale: 1, lane: 0,
      cardSize: size, obstacles: [obstacle])
    for step in 0...100 { #expect(!obstacle.contains(route.point(at: Double(step) / 100))) }
  }

  @Test func largeArtworkBecomesBoundedThumbnailAndCorruptBytesFailSafely() throws {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 800,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    let image = try #require(GraphThumbnail.decode(data))
    #expect(image.size.width == 192 && image.size.height == 128)
    #expect(GraphThumbnail.decode(Data("not artwork".utf8)) == nil)
  }
}
