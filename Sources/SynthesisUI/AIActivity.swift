import SwiftUI
import SynthesisCore

/// Native adaptation of Kokonut UI AI Loading / AI Tool Calls (MIT, kokonut-labs).
/// Explicit events only: no demo playback, inferred reasoning, or invented tool executions.
struct AIActivityView: View {
  let steps: [AgentActivity]
  let t: Theme
  @State private var expanded = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var finished: Bool { !steps.isEmpty && !steps.contains { $0.state == .running } }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { expanded.toggle() }
      } label: {
        HStack(spacing: 9) {
          if finished {
            StudioIcon("checkmark.circle", size: 15).foregroundStyle(t.positive)
          } else {
            ActivitySpinner(t: t)
          }
          Text(
            steps.last(where: { $0.state == .running })?.title
              ?? (finished ? "World context prepared" : "Preparing your conversation")
          )
          .font(.studio(size: 13, weight: .medium)).foregroundStyle(t.secondary)
          .lineLimit(1)
          StudioIcon("chevron.right", size: 10).rotationEffect(.degrees(expanded ? 90 : 0))
            .foregroundStyle(t.muted)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel(
        expanded ? "Collapse assistant activity" : "Expand assistant activity")
      if expanded && !steps.isEmpty {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(steps) { step in
            HStack(alignment: .top, spacing: 12) {
              StudioIcon(icon(step), size: 13)
                .foregroundStyle(step.state == .failed ? t.danger : t.accent)
                .frame(width: 16, height: 18)
              VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.studio(size: 13, weight: .medium))
                  .foregroundStyle(step.state == .running ? t.text : t.secondary)
                if !step.detail.isEmpty {
                  Text(step.detail).font(.studio(size: 12)).foregroundStyle(t.muted)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
              }
              Spacer(minLength: 8)
              if let end = step.endedAt {
                Text(String(format: "%.1fs", max(0, end.timeIntervalSince(step.startedAt))))
                  .font(.studio(size: 11.5)).monospacedDigit().foregroundStyle(t.muted)
              }
            }.transition(.opacity.combined(with: .offset(y: 4)))
          }
        }.padding(.leading, 23).padding(.vertical, 3)
          .overlay(alignment: .leading) {
            Rectangle().fill(t.border).frame(width: 1).padding(.leading, 7)
          }.transition(.opacity.combined(with: .move(edge: .top)))
      }
    }.animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: steps)
      .task(id: finished) {
        guard finished else {
          expanded = true
          return
        }
        do {
          try await Task.sleep(for: .milliseconds(650))
          withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { expanded = false }
        } catch {}
      }
  }
  private func icon(_ step: AgentActivity) -> String {
    if step.state == .failed { return "exclamationmark.circle" }
    if step.state == .cancelled { return "stop.fill" }
    switch step.id {
    case "lore": return "magnifyingglass"
    case "review": return "square.stack.3d.up"
    default: return "sparkles"
    }
  }
}

private struct ActivitySpinner: View {
  let t: Theme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var spinning = false
  var body: some View {
    ZStack {
      Circle().stroke(t.border, lineWidth: 1.5)
      Circle().trim(from: 0, to: 0.27).stroke(
        t.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
      )
      .rotationEffect(.degrees(spinning && !reduceMotion ? 360 : 0))
    }.frame(width: 15, height: 15).accessibilityHidden(true)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spinning = true }
      }
  }
}
