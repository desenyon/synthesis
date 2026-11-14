import AppKit
import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct CanvasBoundaryTests {
  @Test func staleCanvasMessagesAreRejected() {
    #expect(CanvasMessageScope.accepts(["sessionID": "current"], current: "current"))
    #expect(!CanvasMessageScope.accepts(["sessionID": "old"], current: "current"))
    #expect(!CanvasMessageScope.accepts([:], current: "current"))
    #expect(CanvasMessageScope.accepts(["type": "ready"], current: "current"))
  }
  @Test func importedTIFFIsActuallyConvertedToPNG() throws {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 8,
        pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let tiff = try #require(bitmap.representation(using: .tiff, properties: [:]))
    let encoded = try browserImageBase64(tiff, limit: 100_000)
    let data = try #require(Data(base64Encoded: encoded))
    #expect(Array(data.prefix(8)) == [137, 80, 78, 71, 13, 10, 26, 10])
    #expect(NSImage(data: data) != nil)
  }
  @Test func corruptAndOversizedImageInputsAreRejected() {
    #expect(throws: (any Error).self) { try browserImageBase64(Data([1, 2, 3]), limit: 100) }
    #expect(throws: (any Error).self) {
      try browserImageBase64(Data(repeating: 0, count: 200), limit: 100)
    }
  }
  @Test func generatedArtworkIsDecodableAndWithinCanvasLimit() throws {
    for asset in StudioArtwork.allCases {
      let data = try #require(asset.data)
      #expect(data.count < 4_000_000)
      #expect(NSImage(data: data) != nil)
    }
  }
  @Test func recordPickerCanFindBeyondTheOldMenuLimitAndByAlias() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Picker test")
    for index in 0..<90 {
      _ = try store.createRecord(worldID: world.id, title: "Record \(index)")
    }
    let target = try store.createRecord(worldID: world.id, title: "Last record")
    _ = try store.saveMetadata(
      worldID: world.id, id: target.id, version: target.version,
      tags: [], aliases: ["Hidden name"])
    let all = try store.records(worldID: world.id)
    #expect(RecordChoices.matching(all, query: "  ").count == 91)
    #expect(RecordChoices.matching(all, query: " hidden NAME ").map(\.id) == [target.id])
  }

}
