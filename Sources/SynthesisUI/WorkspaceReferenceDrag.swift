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

struct WorkspaceReferenceDragSession {
  let id = UUID()
  let reference: WorldReference
  var receiving = false
}

struct WorkspaceReferenceDelivery {
  let id: UUID
  let reference: WorldReference
  let location: NavigationLocation
}

typealias WorkspaceReferenceDropAction = @MainActor (WorldReferenceSource) async throws -> Bool

extension Studio {
  func beginWorkspaceReferenceDrag(_ reference: WorldReference, monitor: Bool = true) throws
    -> NSItemProvider
  {
    _ = try store.resolveReference(reference, worldID: worldID)
    let provider = try WorkspaceReferenceDrag.provider(reference)
    endRecordDrag()
    workspaceReferenceDrag = WorkspaceReferenceDragSession(reference: reference)
    if monitor { monitorWorkspaceDragEnd() }
    return provider
  }

  /// Outside drops and cancelled gestures must release temporary targets above AppKit/WebKit.
  func monitorWorkspaceDragEnd() {
    let started = Date()
    let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] timer in
      MainActor.assumeIsolated {
        guard let self else {
          timer.invalidate()
          return
        }
        guard self.canReceiveWorkspaceReference else { return }
        if Date().timeIntervalSince(started) > 0.25 && NSEvent.pressedMouseButtons == 0 {
          self.endRecordDrag()
        }
      }
    }
    workspaceDragTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  var canReceiveWorkspaceReference: Bool {
    recordDrag?.receiving == false || workspaceReferenceDrag?.receiving == false
  }

  func claimWorkspaceReferenceDrop() -> WorkspaceReferenceDelivery? {
    let location = navigationLocation
    if let drag = recordDrag, !drag.receiving {
      recordDrag?.receiving = true
      return WorkspaceReferenceDelivery(
        id: drag.id,
        reference: WorldReference(
          worldID: drag.address.worldID, kind: .record, id: drag.address.recordID),
        location: location)
    }
    if let drag = workspaceReferenceDrag, !drag.receiving {
      workspaceReferenceDrag?.receiving = true
      return WorkspaceReferenceDelivery(id: drag.id, reference: drag.reference, location: location)
    }
    return nil
  }

  func isCurrentWorkspaceReferenceDrop(_ delivery: WorkspaceReferenceDelivery) -> Bool {
    recordDrag?.id == delivery.id || workspaceReferenceDrag?.id == delivery.id
  }

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
        let kind = source.boardKind ?? "canvas"
        openBoard(boardID, kind: kind)
        guard navigationLocation.boardID == boardID else { return true }
        if reference.kind == .canvasImage { canvas().revealImage(reference) }
        inspect(.board(boardID, kind: kind))
      }
    } catch {
      show(error.localizedDescription, icon: "exclamationmark.triangle")
    }
    return true
  }

  /// Revalidation happens after asynchronous pasteboard delivery and before any target mutation.
  @discardableResult func receiveWorkspaceReference(
    _ data: Data?, delivery: WorkspaceReferenceDelivery,
    receive: WorkspaceReferenceDropAction
  ) async -> Bool {
    guard isCurrentWorkspaceReferenceDrop(delivery) else { return false }
    defer {
      if isCurrentWorkspaceReferenceDrop(delivery) { endRecordDrag() }
    }
    do {
      guard let data else {
        throw SynthesisError.invalid("This reference could not be read. Drag it again.")
      }
      let source = try resolveDroppedReference(data, at: delivery.location)
      guard source.reference == delivery.reference else {
        throw SynthesisError.invalid("This is not the original reference. Drag it again.")
      }
      guard try await receive(source) else { return false }
      if isCurrentWorkspaceReferenceDrop(delivery) { endRecordDrag(completed: true) }
      return true
    } catch {
      if isCurrentWorkspaceReferenceDrop(delivery) {
        show(error.localizedDescription, icon: "exclamationmark.triangle")
      }
      return false
    }
  }

  private func resolveDroppedReference(_ data: Data, at location: NavigationLocation) throws
    -> WorldReferenceSource
  {
    guard navigationLocation == location else {
      throw SynthesisError.invalid("The workspace changed. Drop the reference again.")
    }
    return try store.resolveReference(WorldReference.decode(data), worldID: worldID)
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
    studio: Studio, receive: @escaping @MainActor (WorldReferenceSource) -> Bool
  ) -> some View {
    workspaceReferenceDrop(studio: studio, target: { _ in receive })
  }

  /// Resolve destination state before asking an item provider to deliver its data.
  func workspaceReferenceDrop(
    studio: Studio, enabled: Bool = true,
    target: @escaping @MainActor (CGPoint) -> WorkspaceReferenceDropAction?
  ) -> some View {
    modifier(WorkspaceReferenceDestination(studio: studio, enabled: enabled, target: target))
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
          return try studio.beginWorkspaceReferenceDrag(reference)
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
  let enabled: Bool
  var target: @MainActor (CGPoint) -> WorkspaceReferenceDropAction?
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
        studio: studio, targeted: $targeted, enabled: enabled, target: target)
    )
    .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: targeted)
  }
}

private struct WorkspaceReferenceReceiver: DropDelegate {
  let studio: Studio
  @Binding var targeted: Bool
  let enabled: Bool
  let target: @MainActor (CGPoint) -> WorkspaceReferenceDropAction?
  func validateDrop(info: DropInfo) -> Bool {
    enabled && studio.canReceiveWorkspaceReference
      && info.hasItemsConforming(to: [WorkspaceReferenceDrag.type])
  }
  func dropEntered(info: DropInfo) { targeted = true }
  func dropExited(info: DropInfo) { targeted = false }
  func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }
  func performDrop(info: DropInfo) -> Bool {
    targeted = false
    let providers = info.itemProviders(for: [WorkspaceReferenceDrag.type])
    guard enabled, providers.count == 1, let provider = providers.first,
      let receive = target(info.location), let delivery = studio.claimWorkspaceReferenceDrop()
    else { return false }
    provider.loadDataRepresentation(forTypeIdentifier: WorkspaceReferenceDrag.type.identifier) {
      data, _ in
      Task { @MainActor in
        await studio.receiveWorkspaceReference(data, delivery: delivery, receive: receive)
      }
    }
    return true
  }
}
