import SwiftUI

/// Contextual conversation opens above the workspace without resizing its map, graph or tree.
struct FloatingCompanion: View {
  @ObservedObject var studio: Studio
  var available: CGSize
  var body: some View {
    ConversationStudio(studio: studio, companion: true)
      .environment(\.barInset, 0)
      .frame(
        width: min(max(300, available.width - 28), studio.companionWidth),
        height: max(260, min(720, available.height - Metric.bar - 28))
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(studio.t.border, lineWidth: 1))
      .elevation(.companion, t: studio.t)
      .overlay(alignment: .leading) {
        PanelResizeHandle(
          studio: studio, panel: .companion,
          displayedWidth: min(max(300, available.width - 28), studio.companionWidth),
          maximum: max(320, available.width - 28), divider: false)
      }
  }
}
