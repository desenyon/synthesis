import SwiftUI
import SynthesisCore

/// Names a new what-if copy of the open world.
struct WhatIfSheet: View {
  @ObservedObject var studio: Studio
  @State private var name = ""
  private var empty: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var body: some View {
    let parent = studio.world?.name ?? "this world"
    SheetScaffold(
      title: "New what-if",
      subtitle:
        "A separate copy of \(parent) to explore freely. Nothing here changes \(parent) until you send changes back and accept them in its Review.",
      t: studio.t, width: 480, close: { studio.sheet = nil }
    ) {
      FormField(
        label: "Name", placeholder: "What if the sea never froze?", text: $name, t: studio.t
      ) { if !empty { studio.createWhatIf(name) } }
      Text(
        "Everything is copied, including history and canon. Changes made in the what-if stay there."
      ).font(.studio(size: 12.5)).foregroundStyle(studio.t.muted)
        .fixedSize(horizontal: false, vertical: true)
    } footer: {
      Spacer()
      Button("Cancel") { studio.sheet = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create what-if") { studio.createWhatIf(name) }
        .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(empty)
    }.onAppear {
      if studio.captureHint == "what-if-new" { name = "What if the sea never froze?" }
    }
  }
}

/// Previews what sending a what-if back would propose, then stages it for review.
struct SendWhatIfSheet: View {
  @ObservedObject var studio: Studio
  @State private var changes: [BranchChange] = []
  var body: some View {
    let parent = studio.branch?.parentName ?? "the original"
    let sendable = changes.filter(\.sendable)
    SheetScaffold(
      title: "Send changes to \(parent)",
      subtitle:
        "These become one proposal in \(parent)'s Review. Accept or dismiss each change there; accepted text is a draft until you review it for canon.",
      t: studio.t, width: 600, close: { studio.sheet = nil }
    ) {
      if changes.isEmpty {
        Text("Nothing has changed in this what-if yet.").font(.studio(size: 13.5))
          .foregroundStyle(studio.t.secondary).padding(.vertical, 12)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 1) {
            ForEach(changes) { change in row(change) }
          }
        }.frame(maxHeight: 360)
      }
    } footer: {
      if changes.count > sendable.count {
        Text("\(changes.count - sendable.count) not sent").font(.studio(size: 12.5))
          .foregroundStyle(studio.t.muted)
      }
      Spacer()
      Button("Cancel") { studio.sheet = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button(sendable.isEmpty ? "Nothing to send" : "Send \(sendable.count) for review") {
        studio.sendWhatIf()
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(sendable.isEmpty)
    }.onAppear {
      studio.perform { changes = try studio.store.branchChanges(worldID: studio.worldID) }
    }
  }
  private func row(_ change: BranchChange) -> some View {
    let (label, icon): (String, String) =
      switch change.kind {
      case .revise: ("Revise", "pencil.line")
      case .create: ("New", "plus")
      case .relate: ("Relationship", "arrow.triangle.branch")
      case .event: ("Event", "calendar")
      case .conflict: ("Changed in both", "exclamationmark.triangle")
      case .archived: ("Archived here", "archivebox")
      case .unsupported: ("Not carried", "minus")
      }
    return HStack(alignment: .top, spacing: 10) {
      StudioIcon(icon, size: 13)
        .foregroundStyle(change.sendable ? studio.t.accent : studio.t.warning)
        .frame(width: 26, height: 26)
        .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 7))
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(label).font(.studio(size: 11.5, weight: .medium)).foregroundStyle(studio.t.muted)
          if !change.sendable {
            Text("· not sent").font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
          }
        }
        Text(change.title).font(.studio(size: 13.5, weight: .medium)).lineLimit(2)
        Text(change.detail).font(.studio(size: 12.5)).foregroundStyle(studio.t.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }.padding(.vertical, 8).padding(.horizontal, 4)
      .opacity(change.sendable ? 1 : 0.8)
  }
}
