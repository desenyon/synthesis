import Foundation
import Testing

@testable import SynthesisUI

struct AtlasAuthoringTests {
  @Test func mapToolsCannotLeakAnUnfinishedRegionIntoMarkerPlacement() {
    var draft = AtlasAuthoring()
    draft.choose(.region(record: "coast", replacing: "old-boundary"))
    draft.addPoint(CGPoint(x: 0.2, y: 0.3))
    draft.choose(.marker("harbour"))
    #expect(draft.markerID == "harbour")
    #expect(draft.regionRecordID == nil && draft.replacedRegionID == nil)
    #expect(draft.points.isEmpty)
    draft.addPoint(CGPoint(x: 0.5, y: 0.5))
    #expect(draft.points.isEmpty)
    draft.choose(.region(record: "island", replacing: nil))
    #expect(draft.markerID == nil)
    draft.addPoint(CGPoint(x: -0.2, y: 1.2))
    draft.addPoint(CGPoint(x: Double.nan, y: 0))
    #expect(draft.points == [CGPoint(x: 0, y: 1)])
    draft.undoPoint()
    #expect(draft.points.isEmpty)
    for _ in 0..<210 { draft.addPoint(CGPoint(x: 0.4, y: 0.6)) }
    #expect(draft.points.count == 200)
    draft.choose(.browse)
    #expect(draft.points.isEmpty && draft.regionRecordID == nil)
  }
}
