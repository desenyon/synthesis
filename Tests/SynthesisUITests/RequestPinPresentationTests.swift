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

  @Test func exclusionMasksHideSavedAndPinnedChipsWithoutDeletingSavedPreferences() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let world = studio.worldID
    let source = try store.createRecord(worldID: world, title: "An unfinished account")
    let branch = try store.createChronologyLane(
      worldID: world, name: "Hidden history", kind: "branch")
    let period = try store.createChronologyLane(
      worldID: world, name: "Later years", kind: "period", parentID: branch.id)
    _ = try store.saveChronologyEvent(
      worldID: world, id: nil, title: "The crossing", date: "", source: source.id, order: nil,
      laneID: period.id)
    try studio.reload()
    studio.updateContext {
      $0.recordIDs = [source.id]
      $0.laneIDs = [period.id]
    }
    studio.updateRequestPins {
      $0.recordIDs = [source.id]
      $0.laneIDs = [period.id]
    }
    #expect(studio.composerAttachments.count == 2)
    studio.updateContext { $0.excludedLaneIDs = [branch.id] }
    #expect(studio.composerAttachments.isEmpty)
    #expect(studio.activeRequestPins.isEmpty)
    #expect(studio.contextOptions.recordIDs == [source.id])
    #expect(studio.contextOptions.laneIDs == [period.id])

    studio.updateContext {
      $0.excludedLaneIDs = []
      $0.canonOnly = true
    }
    #expect(studio.composerAttachments.map(\.key) == [period.id])
    studio.updateContext { $0.canonOnly = false }
    #expect(studio.composerAttachments.map(\.key) == [source.id, period.id])
  }
}
