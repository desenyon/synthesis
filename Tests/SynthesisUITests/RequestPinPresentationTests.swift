import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct RequestPinPresentationTests {
  @Test func overlappingPinsHaveOneChipAndRemovingAPinKeepsTheAttachment() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let mira = try store.createRecord(worldID: world, title: "Mira Vale", kind: "entity")
    let order = try store.createRecord(worldID: world, title: "Tidekeepers", kind: "entity")
    let period = try store.createChronologyLane(
      worldID: world, name: "The crossing", kind: "period")
    try studio.reload()
    studio.updateContext { $0.recordIDs = [mira.id] }
    studio.updateRequestPins {
      $0.recordIDs = [mira.id, order.id]
      $0.laneIDs = [period.id]
    }

    let chips = studio.composerAttachments
    #expect(chips.count == 3)
    #expect(chips.allSatisfy(\.pinned))
    let miraPin = try #require(chips.first { $0.key == mira.id })
    studio.removeAttachment(miraPin)
    #expect(studio.contextOptions.recordIDs == [mira.id])
    #expect(studio.activeRequestPins.recordIDs == [order.id])
    #expect(studio.composerAttachments.first { $0.key == mira.id }?.pinned == false)

    studio.updateContext { $0.excludedRecordIDs = [order.id, mira.id] }
    #expect(studio.composerAttachments.map(\.key) == [period.id])
    studio.clearRequestPins()
    #expect(studio.composerAttachments.isEmpty)
    #expect(studio.contextOptions.recordIDs == [mira.id])
  }
}
