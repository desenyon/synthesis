import SwiftUI

/// Contextual conversation opens above the workspace without resizing its map, graph or tree.
struct FloatingCompanion: View {
  @ObservedObject var studio: Studio
  var available: CGSize
  @State private var dragStart: Double?
  var body: some View {
    ConversationStudio(studio: studio, companion: true)
      .environment(\.barInset, 0)
      .frame(
        width: min(max(300, available.width - 28), studio.companionWidth),
        height: max(260, min(720, available.height - Metric.bar - 28))
      )
      .clipShape(RoundedRectangle(cornerRadius: 18))
      .overlay(RoundedRectangle(cornerRadius: 18).stroke(studio.t.border, lineWidth: 1))
      .shadow(color: studio.t.shadow.opacity(0.7), radius: 24, y: 8)
      .overlay(alignment: .leading) {
        Color.clear.frame(width: 10).contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 2).onChanged { value in
              if dragStart == nil { dragStart = studio.companionWidth }
              studio.companionWidth = min(
                460, max(320, (dragStart ?? 400) - value.translation.width))
            }.onEnded { _ in
              dragStart = nil
              studio.perform {
                try studio.store.setPreference(
                  "companion-width", value: String(studio.companionWidth))
              }
            }
          ).help("Drag to resize the conversation")
      }
  }
}
