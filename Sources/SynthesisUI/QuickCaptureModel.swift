import Combine
import Foundation
import SynthesisCore

/// Quick capture owns its draft and destination independently of the main workspace.
@MainActor final class QuickCaptureModel: ObservableObject {
  let store: WorkspaceStore
  @Published private(set) var worlds: [World] = []
  @Published private(set) var worldID = ""
  @Published private(set) var draft = QuickCaptureDraft()
  @Published var error: String?
  @Published var dark = true
  @Published var oled = false
  @Published var opaqueMaterials = false
  @Published var shortcutUnavailable = false
  @Published private(set) var saved = true
  private var persistence: Task<Void, Never>?
  var didCapture: ((LoreRecord) -> Void)?

  init(store: WorkspaceStore) { self.store = store }

  var t: Theme { Theme(dark: dark, oled: oled) }
  var worldName: String { worlds.first(where: { $0.id == worldID })?.name ?? "Choose a universe" }
  var canSave: Bool {
    !worldID.isEmpty && !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && draft.text.count <= 200_000
  }

  @discardableResult func prepare(worldID preferredWorld: String) -> Bool {
    guard worldID.isEmpty || flush() else { return false }
    do {
      let available = try store.worlds()
      worlds = available
      guard let target = available.first(where: { $0.id == preferredWorld }) ?? available.first
      else {
        throw SynthesisError.invalid("Create a universe in Synthesis before capturing an idea.")
      }
      let restored = try store.quickCaptureDraft(worldID: target.id)
      worldID = target.id
      draft = restored
      saved = true
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  func edit(_ text: String) {
    draft.text = text
    saved = false
    error = nil
    persistence?.cancel()
    persistence = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
      guard !Task.isCancelled else { return }
      self?.flush()
    }
  }

  @discardableResult func selectWorld(_ id: String) -> Bool {
    guard id != worldID else { return true }
    guard flush() else { return false }
    do {
      let next = try store.quickCaptureDraft(worldID: id)
      guard worlds.contains(where: { $0.id == id }) else { throw SynthesisError.notFound }
      worldID = id
      draft = next
      saved = true
      error = nil
      return true
    } catch {
      self.error = error.localizedDescription
      return false
    }
  }

  /// Closing or changing worlds must flush the draft. Failure leaves the panel and text intact.
  @discardableResult func flush() -> Bool {
    persistence?.cancel()
    persistence = nil
    guard !saved else { return true }
    do {
      try store.saveQuickCaptureDraft(worldID: worldID, draft: draft)
      saved = true
      error = nil
      return true
    } catch {
      self.error = "Could not keep this draft. \(error.localizedDescription)"
      return false
    }
  }

  @discardableResult func save() -> LoreRecord? {
    guard canSave else { return nil }
    guard flush() else { return nil }
    do {
      let record = try store.commitQuickCapture(worldID: worldID, draft: draft)
      draft = QuickCaptureDraft()
      saved = true
      error = nil
      didCapture?(record)
      return record
    } catch {
      self.error = "Could not save this idea. \(error.localizedDescription)"
      return nil
    }
  }
}
