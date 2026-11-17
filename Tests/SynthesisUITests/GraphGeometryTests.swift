import SwiftUI
import Testing

@testable import SynthesisUI

struct GraphGeometryTests {
  @Test func atlasButtonZoomKeepsAPannedLandmarkAtTheViewportCentre() {
    let inward = SpatialViewport.zoom(
      scale: 1, pan: CGSize(width: 200, height: -80), factor: 1.25, anchor: .zero,
      limits: 0.5...5)
    // The map point (-200, 80) was at the centre. It must stay there.
    #expect(inward.scale == 1.25)
    #expect(inward.pan == CGSize(width: 250, height: -100))
    #expect(-200 * inward.scale + inward.pan.width == 0)
    #expect(80 * inward.scale + inward.pan.height == 0)
    let outward = SpatialViewport.zoom(
      scale: inward.scale, pan: inward.pan, factor: 0.8, anchor: .zero, limits: 0.5...5)
    #expect(outward.scale == 1 && outward.pan == CGSize(width: 200, height: -80))
  }

  @Test func atlasZoomLimitsKeepThePointerAnchoredWithoutDrift() {
    let inward = SpatialViewport.zoom(
      scale: 4, pan: CGSize(width: 60, height: -20), factor: 2,
      anchor: CGPoint(x: 100, y: 60), limits: 0.5...5)
    #expect(inward.scale == 5 && inward.pan == CGSize(width: 50, height: -40))
    let atLimit = SpatialViewport.zoom(
      scale: inward.scale, pan: inward.pan, factor: 2,
      anchor: CGPoint(x: 100, y: 60), limits: 0.5...5)
    #expect(atLimit.scale == 5 && atLimit.pan == inward.pan)
    let outward = SpatialViewport.zoom(
      scale: 1, pan: CGSize(width: 60, height: -20), factor: 0.1,
      anchor: CGPoint(x: 100, y: 60), limits: 0.5...5)
    #expect(outward.scale == 0.5 && outward.pan == CGSize(width: 80, height: 20))
  }

  @Test func invalidGestureCoordinatesCannotPoisonTheViewport() {
    let pan = CGSize(width: 40, height: -12)
    for anchor in [CGPoint(x: Double.nan, y: 0), CGPoint(x: 0, y: Double.infinity)] {
      let next = SpatialViewport.zoom(scale: 1, pan: pan, factor: 1.2, anchor: anchor)
      #expect(next.scale == 1 && next.pan == pan)
    }
  }

  @Test func zoomPreservesTheAnchoredWorldPointAtEveryScale() {
    for scale in [0.1, 0.18, 0.4, 1.0, 2.2] {
      for factor in [1 / 1.2, 1.2, 100.0, 0.001] {
        let pan = CGSize(width: 213, height: -82)
        let anchor = CGPoint(x: 100, y: -46)
        let next = SpatialViewport.zoom(scale: scale, pan: pan, factor: factor, anchor: anchor)
        #expect(
          abs((anchor.x - pan.width) / scale - (anchor.x - next.pan.width) / next.scale) < 0.00001)
        #expect(
          abs((anchor.y - pan.height) / scale - (anchor.y - next.pan.height) / next.scale) < 0.00001
        )
        #expect((0.1...2.2).contains(next.scale))
      }
    }
    let out = SpatialViewport.zoom(scale: 0.18, pan: .zero, factor: 1 / 1.2, anchor: .zero)
    #expect(out.scale < 0.18, "Zoom out after Fit must not jump inward to 40 percent")
  }

  @Test func directedChainUsesDagreInsteadOfEmergencyGrid() {
    let ids = ["a", "b", "c", "d"]
    let points = GraphLayout.positions(nodes: ids, edges: [("a", "b"), ("b", "c"), ("c", "d")])
    #expect(points["a"]!.x < points["b"]!.x)
    #expect(points["b"]!.x < points["c"]!.x)
    #expect(points["c"]!.x < points["d"]!.x)
    #expect(Set(points.values.map(\.y)).count == 1)
  }
  @Test func bundledEngineLaysOutCyclesWithoutCardOverlap() {
    #expect(GraphLayout.engineAvailable)
    let ids = ["a", "b", "c", "d", "isolated"]
    let points = GraphLayout.positions(
      nodes: ids, edges: [("a", "b"), ("b", "c"), ("c", "a"), ("b", "d")])
    #expect(points.count == ids.count)
    for (index, a) in ids.enumerated() {
      for b in ids.dropFirst(index + 1) {
        let dx = abs(points[a]!.x - points[b]!.x)
        let dy = abs(points[a]!.y - points[b]!.y)
        #expect(dx >= GraphLayout.cardSize.width || dy >= GraphLayout.cardSize.height)
      }
    }
  }

  @Test func nearAndCoincidentCardsRouteOutsideTheirContent() {
    for x in [0.0, 12, 240, 290] {
      let route = GraphRoute.between(.zero, CGPoint(x: x, y: 0), scale: 1, lane: 0)
      #expect(route.start.y < -GraphLayout.cardSize.height / 2)
      #expect(route.end.y < -GraphLayout.cardSize.height / 2)
      #expect(route.middle.y < route.start.y)
      #expect(route.start != route.end)
      #expect(
        [route.start, route.first, route.second, route.end].allSatisfy {
          $0.x.isFinite && $0.y.isFinite
        })
    }
  }

  @Test func fittedCardsKeepDirectRoutes() {
    let scale = 0.47
    let route = GraphRoute.between(.zero, CGPoint(x: 382 * scale, y: 0), scale: scale, lane: 0)
    #expect(route.start.y == 0)
    #expect(route.end.y == 0)
  }

  @Test func parallelEdgesSeparateAndPortsRespectZoom() {
    let a = CGPoint.zero
    let b = CGPoint(x: 600, y: 30)
    let up = GraphRoute.between(a, b, scale: 1, lane: -30)
    let down = GraphRoute.between(a, b, scale: 1, lane: 30)
    #expect(up.middle.y < down.middle.y)
    #expect(up.start.x == GraphLayout.cardSize.width / 2 + 7)
    let small = GraphRoute.between(a, b, scale: 0.5, lane: 0)
    #expect(small.start.x < up.start.x)
  }
}
