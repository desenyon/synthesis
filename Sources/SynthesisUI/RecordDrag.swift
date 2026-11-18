import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

/// A local reference, not exported lore. The receiving workspace resolves the latest record.
struct RecordDragAddress: Codable, Equatable, Sendable {
  static let type = UTType(
    exportedAs: "dev.desenyon.synthesis.record-reference", conformingTo: .data)
  var version = 1
  let worldID: String
  let recordID: String

  func provider() throws -> NSItemProvider {
    let data = try JSONEncoder().encode(self)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(
      forTypeIdentifier: Self.type.identifier, visibility: .ownProcess
    ) {
      completion in
      completion(data, nil)
      return nil
    }
    try WorkspaceReferenceDrag.register(
      WorldReference(worldID: worldID, kind: .record, id: recordID), on: provider)
    return provider
  }
  static func decode(_ data: Data) throws -> Self {
    guard data.count <= 2048, let value = try? JSONDecoder().decode(Self.self, from: data),
      value.version == 1, !value.worldID.isEmpty, !value.recordID.isEmpty,
      value.worldID.utf8.count <= 128, value.recordID.utf8.count <= 128
    else { throw SynthesisError.invalid("This is not a valid Synthesis record reference.") }
    return value
  }
}

struct RecordDragSession: Identifiable {
  let id = UUID()
  let address: RecordDragAddress
  var receiving = false
}

enum RecordDropTarget {
  case main, beside
  case canvas(boardID: String, sessionID: String, point: CGPoint)
}

extension Studio {
  func beginRecordDrag(_ record: LoreRecord, monitor: Bool = true) -> NSItemProvider {
    guard record.worldID == worldID,
      (try? store.isArchived(worldID: worldID, recordID: record.id)) == false
    else { return NSItemProvider() }
    let address = RecordDragAddress(worldID: worldID, recordID: record.id)
    guard let provider = try? address.provider() else { return NSItemProvider() }
    endRecordDrag()
    recordDrag = RecordDragSession(address: address)
    if monitor { monitorWorkspaceDragEnd() }
    return provider
  }
  func endRecordDrag(completed: Bool = false) {
    workspaceDragTimer?.invalidate()
    workspaceDragTimer = nil
    recordDrag = nil
    workspaceReferenceDrag = nil
    if completed {
      palette = false
      mobileNavigation = false
    }
  }

  /// Re-check both the source and destination after the item provider delivers its data.
  @discardableResult func receiveRecordDrop(
    _ data: Data, target: RecordDropTarget, location: NavigationLocation, dragID: UUID
  ) async -> Bool {
    guard recordDrag?.id == dragID else { return false }
    defer { if recordDrag?.id == dragID { endRecordDrag() } }
    do {
      let address = try RecordDragAddress.decode(data)
      guard address == recordDrag?.address, address.worldID == worldID,
        navigationLocation == location
      else { throw SynthesisError.invalid("The workspace changed. Drag the record again.") }
      guard try !store.isArchived(worldID: worldID, recordID: address.recordID) else {
        throw SynthesisError.invalid("This record was archived. Restore it before opening it.")
      }
      let record = try store.record(worldID: worldID, id: address.recordID)
      guard flushEditor() else { return false }
      switch target {
      case .main:
        openRecord(record)
        guard selectedRecord?.id == record.id else { return false }
      case .beside:
        openBeside(record)
        guard splitRecord?.id == record.id else { return false }
      case .canvas(let boardID, let sessionID, let point):
        guard destination == .canvas, selectedRecord == nil, let session = canvasSession else {
          throw SynthesisError.invalid("Open a canvas before placing a record.")
        }
        try await session.drop(record, at: point, boardID: boardID, sessionID: sessionID)
        show("Placed \(record.title) on the canvas")
      }
      if recordDrag?.id == dragID { endRecordDrag(completed: true) }
      return true
    } catch {
      show(error.localizedDescription, icon: "exclamationmark.triangle")
      return false
    }
  }
}

private struct RecordDragModifier: ViewModifier {
  @ObservedObject var studio: Studio
  let record: LoreRecord?
  @ViewBuilder func body(content: Content) -> some View {
    if let record {
      content.onDrag {
        studio.beginRecordDrag(record)
      } preview: {
        HStack(spacing: 10) {
          StudioIcon(recordIcon(record), size: 17).foregroundStyle(studio.t.secondary)
          Text(record.title).font(.studio(.control)).lineLimit(1)
        }.padding(12).frame(maxWidth: 280).foregroundStyle(studio.t.text)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
      }
    } else {
      content
    }
  }
}
extension View {
  func recordDraggable(_ record: LoreRecord?, studio: Studio) -> some View {
    modifier(RecordDragModifier(studio: studio, record: record))
  }
}

/// Mounted only for an internal record drag. Normal editor and WebKit input is untouched.
struct RecordDropSurface: View {
  @ObservedObject var studio: Studio
  let title: String
  let icon: String
  let target: (CGPoint) -> RecordDropTarget
  @State private var targeted = false
  var body: some View {
    if studio.recordDrag != nil {
      ZStack {
        RoundedRectangle(cornerRadius: Metric.radius)
          .fill(studio.t.accent.opacity(targeted ? 0.12 : 0.025))
        RoundedRectangle(cornerRadius: Metric.radius)
          .strokeBorder(studio.t.accent.opacity(targeted ? 0.7 : 0.25), lineWidth: 1)
        HStack(spacing: 8) {
          StudioIcon(icon, size: 16)
          Text(title).font(.studio(.control)).lineLimit(2)
        }.foregroundStyle(studio.t.text).padding(12)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(studio.t.hairline))
          .padding(12)
      }.contentShape(Rectangle())
        .onDrop(
          of: [RecordDragAddress.type],
          delegate: RecordDropReceiver(studio: studio, targeted: $targeted, target: target)
        )
        .accessibilityLabel(title)
    }
  }
}

private struct RecordDropReceiver: DropDelegate {
  let studio: Studio
  @Binding var targeted: Bool
  let target: (CGPoint) -> RecordDropTarget
  func validateDrop(info: DropInfo) -> Bool {
    studio.recordDrag?.receiving == false
      && info.hasItemsConforming(to: [RecordDragAddress.type])
  }
  func dropEntered(info: DropInfo) { targeted = true }
  func dropExited(info: DropInfo) { targeted = false }
  func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
  func performDrop(info: DropInfo) -> Bool {
    targeted = false
    let providers = info.itemProviders(for: [RecordDragAddress.type])
    guard providers.count == 1, let provider = providers.first, let drag = studio.recordDrag,
      !drag.receiving
    else {
      return false
    }
    let destination = target(info.location)
    let location = studio.navigationLocation
    studio.recordDrag?.receiving = true
    provider.loadDataRepresentation(forTypeIdentifier: RecordDragAddress.type.identifier) {
      data, _ in
      Task { @MainActor in
        guard let data else {
          if studio.recordDrag?.id == drag.id {
            studio.endRecordDrag()
            studio.show(
              "This record could not be read. Drag it again.", icon: "exclamationmark.triangle")
          }
          return
        }
        await studio.receiveRecordDrop(
          data, target: destination, location: location, dragID: drag.id)
      }
    }
    return true
  }
}
