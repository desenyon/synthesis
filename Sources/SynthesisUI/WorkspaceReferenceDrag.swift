import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

enum WorkspaceReferenceDrag {
  static let type = UTType(
    exportedAs: "dev.desenyon.synthesis.world-reference", conformingTo: .data)

  static func register(_ reference: WorldReference, on provider: NSItemProvider) throws {
    try reference.validate()
    let data = try JSONEncoder().encode(reference)
    provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .ownProcess)
    {
      completion in
      completion(data, nil)
      return nil
    }
  }

  static func provider(_ reference: WorldReference) throws -> NSItemProvider {
    let provider = NSItemProvider()
    try register(reference, on: provider)
    return provider
  }
}

extension Studio {
  @discardableResult func appendWorkspaceReference(_ reference: WorldReference) -> Bool {
    do {
      let source = try store.resolveReference(reference, worldID: worldID)
      let current =
        pendingComposer.flatMap {
          $0.world == worldID && $0.base == draft ? $0.text : nil
        } ?? draft
      let separator = current.isEmpty || current.last?.isWhitespace == true ? "" : " "
      let next = current + separator + source.markdown + " "
      guard next.count <= 300_000 else {
        throw SynthesisError.invalid("Shorten this message before adding another reference.")
      }
      try store.setPreference("composer:\(worldID)", value: next)
      pendingComposer = nil
      draft = next
      return true
    } catch {
      show(error.localizedDescription, icon: "exclamationmark.triangle")
      return false
    }
  }

  /// Returns whether this was a Synthesis reference URL, including a locally explained failure.
  @discardableResult func openWorkspaceReference(_ url: URL) -> Bool {
    guard url.scheme == "synthesis", url.host == "reference" else { return false }
    do {
      let reference = try WorldReference(url: url)
      let source = try store.resolveReference(reference, worldID: worldID)
      guard flushEditor() else { return true }
      switch reference.kind {
      case .record:
        openRecord(try store.record(worldID: worldID, id: reference.id))
      case .event:
        withNavigation {
          navigate(.timeline)
          timelineLaneID = nil
          inspect(.event(reference.id))
        }
      case .proposal:
        openProposalReview(reference.id)
        inspect(.proposal(reference.id))
      case .artwork:
        if let id = source.recordIDs.first {
          openRecord(try store.record(worldID: worldID, id: id))
          inspect(.record(id))
        }
      case .board, .atlasImage, .canvasImage:
        let boardID = reference.containerID ?? reference.id
        openBoard(boardID, kind: source.boardKind ?? "canvas")
        inspect(.board(boardID, kind: source.boardKind ?? "canvas"))
      }
    } catch {
      show(error.localizedDescription, icon: "exclamationmark.triangle")
    }
    return true
  }

  /// Revalidation happens after asynchronous pasteboard delivery and before any target mutation.
  @discardableResult func receiveWorkspaceReference(
    _ data: Data, at location: NavigationLocation, receive: (WorldReferenceSource) -> Bool
  ) -> Bool {
    do {
      guard navigationLocation == location else {
        throw SynthesisError.invalid("The workspace changed. Drop the reference again.")
      }
      let source = try store.resolveReference(WorldReference.decode(data), worldID: worldID)
      guard receive(source) else { return false }
      endRecordDrag(completed: true)
      return true
    } catch {
      show(error.localizedDescription, icon: "exclamationmark.triangle")
      return false
    }
  }
}

extension View {
  func workspaceReferenceDraggable(
    _ reference: WorldReference?, title: String, icon: String, studio: Studio
  ) -> some View {
    modifier(
      WorkspaceReferenceSourceModifier(
        reference: reference, title: title, icon: icon, studio: studio))
  }

  func workspaceReferenceDrop(
    studio: Studio, receive: @escaping (WorldReferenceSource) -> Bool
  ) -> some View {
    modifier(WorkspaceReferenceDestination(studio: studio, receive: receive))
  }
}

private struct WorkspaceReferenceSourceModifier: ViewModifier {
  let reference: WorldReference?
  let title: String
  let icon: String
  @ObservedObject var studio: Studio
  @ViewBuilder func body(content: Content) -> some View {
    if let reference {
      content.onDrag {
        do {
          _ = try studio.store.resolveReference(reference, worldID: studio.worldID)
          return try WorkspaceReferenceDrag.provider(reference)
        } catch {
          studio.show(error.localizedDescription, icon: "exclamationmark.triangle")
          return NSItemProvider()
        }
      } preview: {
        HStack(spacing: Space.sm) {
          StudioIcon(icon, size: 15)
          Text(title).font(.studio(.control)).lineLimit(1)
        }.padding(Space.md).frame(maxWidth: 300).foregroundStyle(studio.t.text)
          .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
      }
    } else {
      content
    }
  }
}

private struct WorkspaceReferenceDestination: ViewModifier {
  @ObservedObject var studio: Studio
  var receive: (WorldReferenceSource) -> Bool
  @State private var targeted = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content.overlay {
      if targeted {
        RoundedRectangle(cornerRadius: Metric.radius).strokeBorder(studio.t.accent, lineWidth: 1)
          .allowsHitTesting(false).accessibilityHidden(true)
      }
    }.onDrop(
      of: [WorkspaceReferenceDrag.type],
      delegate: WorkspaceReferenceReceiver(
        studio: studio, targeted: $targeted, receive: receive)
    )
    .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: targeted)
  }
}

private struct WorkspaceReferenceReceiver: DropDelegate {
  let studio: Studio
  @Binding var targeted: Bool
  let receive: (WorldReferenceSource) -> Bool
  func validateDrop(info: DropInfo) -> Bool {
    info.hasItemsConforming(to: [WorkspaceReferenceDrag.type])
  }
  func dropEntered(info: DropInfo) { targeted = true }
  func dropExited(info: DropInfo) { targeted = false }
  func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
  func performDrop(info: DropInfo) -> Bool {
    targeted = false
    let providers = info.itemProviders(for: [WorkspaceReferenceDrag.type])
    guard providers.count == 1, let provider = providers.first else { return false }
    let location = studio.navigationLocation
    provider.loadDataRepresentation(forTypeIdentifier: WorkspaceReferenceDrag.type.identifier) {
      data, _ in
      Task { @MainActor in
        guard let data else {
          studio.show(
            "This reference could not be read. Drag it again.", icon: "exclamationmark.triangle")
          return
        }
        _ = studio.receiveWorkspaceReference(data, at: location, receive: receive)
      }
    }
    return true
  }
}
