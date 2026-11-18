import SwiftUI
import SynthesisCore

struct RelationshipHistoryTarget: Identifiable {
  let worldID: String
  let relationshipID: String
  let title: String
  var id: String { relationshipID }
}

struct RelationshipHistorySheet: View {
  @ObservedObject var studio: Studio
  let target: RelationshipHistoryTarget
  let close: () -> Void
  @State private var entries: [RelationshipRevision] = []
  @State private var failure: String?
  @State private var hasEarlier = false

  private let pageSize = 25
  private var inScope: Bool { target.worldID == studio.worldID }

  var body: some View {
    SheetScaffold(
      title: "Relationship history", subtitle: target.title, t: studio.t, width: 470, close: close
    ) {
      if !inScope {
        Text("Open this relationship in its original universe to see its history.")
          .font(.studio(.control)).foregroundStyle(studio.t.warning)
      } else if entries.isEmpty, failure == nil {
        Text("No earlier versions have been recorded.")
          .font(.studio(.control)).foregroundStyle(studio.t.secondary)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: Space.md) {
            ForEach(entries) { entry in
              snapshot(entry)
              Divider()
            }
            if let failure {
              Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger)
              Button("Retry") { load(earlier: !entries.isEmpty) }
                .buttonStyle(QuietButton(t: studio.t))
            } else if hasEarlier {
              Button("Show earlier versions") { load(earlier: true) }
                .buttonStyle(QuietButton(t: studio.t))
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxHeight: 400)
      }
    } footer: {
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
    }
    .task(id: studio.worldRevision) { load(earlier: false) }
  }

  private func snapshot(_ entry: RelationshipRevision) -> some View {
    let changes: String =
      switch entry.action {
      case "archive": "Before archive"
      case "rename": "Before label change"
      case "edit": "Before details changed"
      default: "Earlier snapshot"
      }
    let dates = entry.attributes
    let fields = [
      ("Meaning", dates.kind.title),
      ("Start", dates.startLabel.isEmpty ? "Unknown" : dates.startLabel),
      ("End", dates.endLabel.isEmpty ? "Unknown" : dates.endLabel),
      ("Strength", dates.strength.title),
      ("Mutuality", dates.mutuality.title),
      ("Secrecy", dates.secrecy.title),
      ("Status", dates.status.title),
    ]
    return VStack(alignment: .leading, spacing: Space.xs) {
      Text(entry.label).font(.studio(.cardTitle)).textSelection(.enabled)
      Text("\(changes) · \(entry.supersededAt)")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      Text(entry.revision.map { "Revision \($0)" } ?? "Revision number unavailable")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      ForEach(fields, id: \.0) { field in
        Text("\(field.0): \(field.1)").font(.studio(.label)).textSelection(.enabled)
      }
      ForEach(dates.evidenceRecordIDs, id: \.self) { id in
        let title = studio.records.first { $0.id == id && $0.worldID == target.worldID }?.title
        StudioLabel(title ?? "Archived or unavailable evidence", icon: "doc.text")
          .font(.studio(.label)).foregroundStyle(studio.t.secondary)
      }
    }.padding(.vertical, Space.xs)
  }

  private func load(earlier: Bool) {
    guard inScope else { return }
    if !earlier { entries = [] }
    do {
      let page = try studio.store.relationshipHistory(
        worldID: target.worldID, relationshipID: target.relationshipID,
        before: earlier ? entries.last?.cursor : nil, limit: pageSize + 1)
      entries += page.prefix(pageSize)
      hasEarlier = page.count > pageSize
      failure = nil
    } catch {
      failure = error.localizedDescription
    }
  }
}
