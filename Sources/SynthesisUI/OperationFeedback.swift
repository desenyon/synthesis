import SwiftUI
import SynthesisCore

/// A report of an observed operation. No estimated percentages or timer-driven success.
struct OperationFeedback: Equatable {
  enum Phase: Equatable { case waiting, running, complete, failed, cancelled }
  var title: String
  var detail = ""
  var phase: Phase
  var completed: Int?
  var total: Int?

  var fraction: Double? {
    guard let completed, let total, total > 0 else { return nil }
    return Double(min(total, max(0, completed))) / Double(total)
  }
  var icon: String {
    switch phase {
    case .waiting: return "clock"
    case .running: return "arrow.triangle.2.circlepath"
    case .complete: return "checkmark.circle"
    case .failed: return "exclamationmark.circle"
    case .cancelled: return "stop.fill"
    }
  }
}

enum DocumentSaveState: Equatable {
  case saved, waiting, saving, failed
  var feedback: OperationFeedback {
    switch self {
    case .saved:
      return .init(
        title: "Saved", detail: "Saved on this Mac. Search is up to date.", phase: .complete)
    case .waiting:
      return .init(
        title: "Unsaved", detail: "Autosave pending. Search updates with the saved revision.",
        phase: .waiting)
    case .saving:
      return .init(
        title: "Saving…", detail: "Saving this revision and updating local search.", phase: .running
      )
    case .failed:
      return .init(
        title: "Not saved", detail: "Your text is kept here. Resolve the error and retry saving.",
        phase: .failed)
    }
  }
}

struct ReviewProgress: Equatable {
  let worldID: String
  let proposalID: String
  let accept: Bool
  let total: Int
  var summary = ""
  var completed = 0
  var phase = OperationFeedback.Phase.waiting
  var detail = "Saving the canvas before applying your decisions."
  var feedback: OperationFeedback {
    let verb = accept ? "saved as drafts" : "dismissed"
    let title: String
    switch phase {
    case .waiting: title = "Preparing review"
    case .running: title = accept ? "Applying reviewed changes" : "Dismissing changes"
    case .complete: title = "Review complete"
    case .failed: title = "Review needs attention"
    case .cancelled: title = "Review stopped"
    }
    return .init(
      title: title,
      detail:
        "\(summary.isEmpty ? "" : summary + " · ")\(completed) of \(total) \(verb). \(detail)",
      phase: phase,
      completed: completed, total: total)
  }
}

struct OperationFeedbackView: View {
  let feedback: OperationFeedback
  let t: Theme
  var compact = false
  var showDetail = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private var ink: Color {
    switch feedback.phase {
    case .failed: return t.danger
    case .cancelled, .waiting: return t.secondary
    default: return t.muted
    }
  }
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if feedback.phase == .running && !reduceMotion {
        ProgressView().controlSize(.mini).frame(width: 14, height: 16)
      } else {
        StudioIcon(feedback.icon, size: 12).frame(width: 14, height: 16).foregroundStyle(ink)
      }
      if !compact {
        VStack(alignment: .leading, spacing: 5) {
          Text(feedback.title).font(.studio(.captionStrong)).foregroundStyle(ink).lineLimit(1)
          if showDetail && !feedback.detail.isEmpty {
            Text(feedback.detail).font(.studio(.caption)).foregroundStyle(t.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          if showDetail, let fraction = feedback.fraction, feedback.phase != .complete {
            ProgressView(value: fraction).tint(t.secondary).accessibilityLabel(feedback.title)
          }
        }
      }
    }
    .help(feedback.detail)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(feedback.title). \(feedback.detail)")
    .animation(reduceMotion ? nil : Motion.feedbackAnimation, value: feedback.phase)
  }
}

struct ActivitySummary: Equatable {
  let title: String
  let state: AgentActivity.State
  init(_ steps: [AgentActivity]) {
    if let running = steps.last(where: { $0.state == .running }) {
      title = running.title
      state = .running
    } else if let failed = steps.last(where: { $0.state == .failed }) {
      title = failed.title
      state = .failed
    } else if let cancelled = steps.last(where: { $0.state == .cancelled }) {
      title = cancelled.title
      state = .cancelled
    } else {
      title = steps.isEmpty ? "Preparing your conversation" : (steps.last?.title ?? "Complete")
      state = steps.isEmpty ? .running : .complete
    }
  }
}
