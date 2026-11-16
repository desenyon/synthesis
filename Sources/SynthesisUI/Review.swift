import SwiftUI
import SynthesisCore

/// Everything waiting on the creator's judgement in one place: staged AI proposals, drafts that
/// have moved past accepted canon, and a local consistency check that needs no model.
struct ReviewScreen: View {
  enum Tab: String, CaseIterable {
    case proposals = "Proposals"
    case canon = "Canon"
    case checks = "Checks"
  }
  @ObservedObject var studio: Studio
  @State private var tab = Tab.proposals
  @State private var findings: [WorldFinding] = []
  @State private var dismissed = 0
  @State private var chosen = false
  @State private var query = ""
  @State private var oldestFirst = false
  private var filteredProposals: [Proposal] {
    studio.pendingProposals.filter {
      query.isEmpty || $0.summary.localizedCaseInsensitiveContains(query)
        || $0.changes.contains { ($0.title ?? "").localizedCaseInsensitiveContains(query) }
    }
    .sorted { oldestFirst ? $0.createdAt < $1.createdAt : $0.createdAt > $1.createdAt }
  }
  var body: some View {
    let queue = studio.canonQueue.filter {
      query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
    }
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(
          icon: Destination.review.icon, title: "Review",
          detail: studio.reviewCount == 0 && findings.isEmpty
            ? "Nothing waiting" : "Your decisions, in one place", t: studio.t)
      } trailing: {
        SearchField(text: $query, placeholder: "Find a change", t: studio.t).frame(maxWidth: 210)
        IconButton(
          icon: "arrow.up.arrow.down",
          label: oldestFirst ? "Oldest first; switch to newest" : "Newest first; switch to oldest",
          t: studio.t
        ) { oldestFirst.toggle() }
      }
      HStack(spacing: 6) {
        FilterChip(
          title: "Proposals", count: studio.pendingProposals.count, selected: tab == .proposals,
          t: studio.t
        ) { tab = .proposals }
        FilterChip(title: "Canon", count: queue.count, selected: tab == .canon, t: studio.t) {
          tab = .canon
        }
        FilterChip(title: "Checks", count: findings.count, selected: tab == .checks, t: studio.t) {
          tab = .checks
        }
        Spacer()
      }.padding(.horizontal, 20).padding(.bottom, 10)
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          switch tab {
          case .proposals: proposals
          case .canon: canon(queue)
          case .checks: checks
          }
        }.padding(.horizontal, 24).padding(.vertical, 18).frame(maxWidth: 820, alignment: .leading)
          .frame(maxWidth: .infinity)
      }
    }
    .onAppear {
      refresh()
      if studio.captureHint == "review-canon" {
        tab = .canon
      } else if studio.captureHint == "review-checks" {
        tab = .checks
      } else if !chosen {
        // Open on the first tab that has something in it.
        tab =
          !studio.pendingProposals.isEmpty
          ? .proposals
          : (!studio.canonQueue.isEmpty ? .canon : (findings.isEmpty ? .proposals : .checks))
      }
      chosen = true
    }
    .onChange(of: studio.records) { _, _ in refresh() }
  }
  private func refresh() {
    findings = (try? studio.store.worldChecks(worldID: studio.worldID)) ?? []
    dismissed = (try? studio.store.dismissedCheckCount(worldID: studio.worldID)) ?? 0
  }
  private func intro(_ text: String) -> some View {
    Text(text).font(.studio(size: 13)).foregroundStyle(studio.t.secondary).lineSpacing(3)
      .fixedSize(horizontal: false, vertical: true)
  }

  // MARK: Proposals

  @ViewBuilder private var proposals: some View {
    if studio.pendingProposals.isEmpty {
      EmptyState(
        icon: "square.stack.3d.up", title: "No proposals waiting",
        message:
          "When the assistant suggests new records, revisions, relationships or events, they wait here until you accept or dismiss each one.",
        t: studio.t
      ) {
        if studio.mode == .assisted {
          Button("Open Conversation") { studio.navigate(.chat) }
            .buttonStyle(QuietButton(t: studio.t))
        }
      }.frame(maxWidth: .infinity).padding(.top, 40)
    } else {
      intro(
        "Changes the assistant has suggested. Accepting saves a draft; canon is decided separately."
      )
      ForEach(filteredProposals) { proposal in
        VStack(alignment: .leading, spacing: 8) {
          if let chat = studio.conversations.first(where: { $0.id == proposal.conversationID }) {
            Button {
              studio.openChat(chat)
            } label: {
              HStack(spacing: 6) {
                StudioIcon("bubble.left", size: 11)
                Text(chat.title).font(.studio(size: 12.5, weight: .medium)).lineLimit(1)
                Text(relativeDate(proposal.createdAt)).font(.studio(size: 12))
                  .foregroundStyle(studio.t.muted)
              }.foregroundStyle(studio.t.secondary).padding(.horizontal, 7).frame(height: 24)
                .hoverFill(studio.t, radius: 6)
            }.buttonStyle(.plain).padding(.leading, -7).help("Open the conversation")
          }
          ProposalCard(studio: studio, proposal: proposal)
        }
      }
    }
  }

  // MARK: Canon

  @ViewBuilder private func canon(_ queue: [LoreRecord]) -> some View {
    if queue.isEmpty {
      EmptyState(
        icon: "checkmark.seal", title: "Canon is up to date",
        message:
          "Records you have accepted as canon appear here when their draft changes, so you can compare and decide.",
        t: studio.t
      ) { EmptyView() }.frame(maxWidth: .infinity).padding(.top, 40)
    } else {
      intro(
        "These drafts differ from the version you accepted. Review shows exactly what would change."
      )
      VStack(spacing: 1) {
        ForEach(queue) { record in
          HStack(spacing: 12) {
            CategoryTile(record: record, t: studio.t, size: 34)
            VStack(alignment: .leading, spacing: 3) {
              Text(record.title).font(.studio(size: 14, weight: .medium)).lineLimit(1)
              Text("Draft changed \(relativeDate(record.updatedAt).lowercased()) · canon preserved")
                .font(.studio(size: 12.5)).foregroundStyle(studio.t.muted).lineLimit(1)
            }
            Spacer(minLength: 12)
            Button("Open") { studio.openRecord(record) }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost))
            Button("Review") {
              studio.reviewCanon = record.id
              studio.openRecord(record)
            }.buttonStyle(QuietButton(t: studio.t, primary: true))
              .help("Compare this draft with accepted canon")
          }.padding(.horizontal, 10).frame(height: 56).hoverFill(studio.t, radius: 9)
        }
      }.padding(.horizontal, -10)
    }
  }

  // MARK: Checks

  private func icon(_ kind: WorldFinding.Kind) -> String {
    switch kind {
    case .duplicateName: return "person.2"
    case .unlinkedMention: return "link.badge.plus"
    case .isolatedEntity: return "circle.dashed"
    case .orphanedEvent: return "calendar.badge.exclamationmark"
    case .emptyRecord: return "doc"
    }
  }
  @ViewBuilder private var checks: some View {
    if findings.isEmpty {
      EmptyState(
        icon: "checkmark.circle", title: "Nothing to flag",
        message:
          "This check runs on your device and looks for clashing names, unlinked mentions, unconnected entities and events without a source.",
        t: studio.t
      ) {
        if dismissed > 0 {
          Button("Show \(dismissed) dismissed") { restore() }.buttonStyle(QuietButton(t: studio.t))
        }
      }.frame(maxWidth: .infinity).padding(.top, 40)
    } else {
      intro(
        "Observations from a local check of this world. No model is involved, and nothing changes unless you choose an action."
      )
      VStack(spacing: 1) {
        ForEach(
          findings.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
              || $0.detail.localizedCaseInsensitiveContains(query)
          }
        ) { finding in row(finding) }
      }.padding(.horizontal, -10)
      if dismissed > 0 {
        Button("Show \(dismissed) dismissed") { restore() }.buttonStyle(.plain)
          .font(.studio(size: 12.5, weight: .medium)).foregroundStyle(studio.t.accent)
      }
    }
  }
  private func row(_ finding: WorldFinding) -> some View {
    let t = studio.t
    let involved = finding.recordIDs.compactMap { id in studio.records.first { $0.id == id } }
    return HStack(alignment: .top, spacing: 12) {
      StudioIcon(icon(finding.kind), size: 14)
        .foregroundStyle(
          finding.kind == .duplicateName || finding.kind == .orphanedEvent ? t.warning : t.secondary
        )
        .frame(width: 34, height: 34).background(t.surface, in: RoundedRectangle(cornerRadius: 8))
      VStack(alignment: .leading, spacing: 3) {
        Text(finding.title).font(.studio(size: 14, weight: .medium))
          .fixedSize(horizontal: false, vertical: true)
        Text(finding.detail).font(.studio(size: 12.5)).foregroundStyle(t.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 12)
      HStack(spacing: 6) {
        if finding.kind == .unlinkedMention, involved.count == 2 {
          Button("Link them") { link(involved[0], involved[1]) }
            .buttonStyle(QuietButton(t: t, primary: true))
        }
        if finding.kind == .orphanedEvent {
          Button("Open Timeline") { studio.navigate(.timeline) }.buttonStyle(QuietButton(t: t))
        } else if involved.count == 1 || finding.kind == .unlinkedMention,
          let first = involved.first
        {
          Button("Open") { studio.openRecord(first) }.buttonStyle(QuietButton(t: t))
        } else if involved.count > 1 {
          PlainMenu {
            ForEach(involved) { record in
              Button(
                "\(record.title) · \(record.category.isEmpty ? Vocabulary.kindLabel(record.kind) : record.category)"
              ) { studio.openRecord(record) }
            }
          } label: {
            Text("Open…").font(.studio(size: 13, weight: .medium)).padding(.horizontal, 12)
              .frame(height: Metric.control)
              .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
              .overlay(
                RoundedRectangle(cornerRadius: Metric.radius).stroke(t.hairline, lineWidth: 1))
          }
        }
        IconButton(icon: "xmark", label: "Dismiss this observation", t: t) {
          studio.perform {
            try studio.store.dismissCheck(worldID: studio.worldID, id: finding.id)
            refresh()
          }
        }
      }
    }.padding(.horizontal, 10).padding(.vertical, 10).hoverFill(t, radius: 9)
  }
  private func link(_ source: LoreRecord, _ target: LoreRecord) {
    studio.perform {
      try studio.store.linkRecord(worldID: studio.worldID, source: source.id, target: target.id)
      refresh()
      studio.show("Linked “\(source.title)” to \(target.title)", icon: "link", actionTitle: "Undo")
      {
        studio.perform {
          try studio.store.unlinkRecord(
            worldID: studio.worldID, source: source.id, target: target.id)
          refresh()
        }
      }
    }
  }
  private func restore() {
    studio.perform {
      try studio.store.restoreChecks(worldID: studio.worldID)
      refresh()
    }
  }
}
