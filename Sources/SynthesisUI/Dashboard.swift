import SwiftUI
import SynthesisCore

extension Studio {
  var dashboardProjects: [LoreRecord] { topLevelRecords.filter(\.isProject) }
  var dashboardEntities: [LoreRecord] {
    topLevelRecords.filter { $0.kind == "entity" && !$0.isProject }
      .sorted { $0.updatedAt == $1.updatedAt ? $0.title < $1.title : $0.updatedAt > $1.updatedAt }
  }
  var dashboardWriting: [LoreRecord] {
    topLevelRecords.filter { $0.kind != "entity" && $0.state != "canon" }
      .sorted { $0.updatedAt == $1.updatedAt ? $0.title < $1.title : $0.updatedAt > $1.updatedAt }
  }
  func createProject(_ title: String) {
    guard flushEditor() else { return }
    perform {
      let project = try store.createProject(worldID: worldID, title: title)
      try reload()
      sheet = nil
      openRecord(project)
    }
  }
  func openProposalReview(_ id: String) {
    withNavigation {
      guard flushEditor() else { return }
      perform {
        _ = try store.proposal(worldID: worldID, id: id)
        navigate(.review)
        reviewSection = .proposals
        reviewFocusID = id
      }
    }
  }
  func openActivity(_ item: WorldActivity) {
    withNavigation {
      guard item.worldID == worldID, flushEditor() else { return }
      perform {
        let target: InspectionTarget
        switch item.kind {
        case .world:
          openSettings(.world)
          return
        case .conversation:
          guard
            let chat = try store.conversations(worldID: worldID).first(where: {
              $0.id == item.objectID
            })
          else { throw SynthesisError.notFound }
          openChat(chat)
          return
        case .record:
          let record = try store.record(worldID: worldID, id: item.objectID)
          guard try !store.isArchived(worldID: worldID, recordID: record.id) else {
            throw SynthesisError.notFound
          }
          openRecord(record)
          return
        case .board:
          openBoard(item.objectID, kind: item.boardKind ?? "canvas")
          return
        case .event: target = .event(item.objectID)
        case .relationship: target = .relationship(item.objectID)
        case .proposal:
          openProposalReview(item.objectID)
          inspect(.proposal(item.objectID))
          return
        case .lane: target = .lane(item.objectID)
        }
        _ = try inspectionData(for: target)
        navigate(item.kind == .relationship ? .knowledge : .timeline)
        if item.kind == .lane { timelineLaneID = item.objectID }
        inspect(target)
      }
    }
  }
}

/// A source-backed return point. It never starts generation or manufactures activity.
struct DashboardScreen: View {
  @ObservedObject var studio: Studio
  @Environment(\.studioDensity) private var density
  @State private var activity: [WorldActivity] = []
  @State private var failure: String?
  private var t: Theme { studio.t }
  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        BarTitle(icon: Destination.dashboard.icon, title: "Dashboard", t: t)
      } trailing: {
        BarAction(title: "New project", icon: "folder", t: t) {
          studio.sheet = .project
        }
        BarAction(title: "Capture idea", icon: "plus", t: t) {
          studio.newRecordKind = "capture"
          studio.sheet = .document
        }
      }
      GeometryReader { geometry in
        ScrollViewReader { scroll in
          ScrollView {
            ContentColumn {
              VStack(alignment: .leading, spacing: density.sectionGap + 12) {
                welcome
                if geometry.size.width >= 900 {
                  HStack(alignment: .top, spacing: 40) {
                    writingColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                    reviewColumn.frame(width: max(280, min(360, geometry.size.width * 0.33)))
                  }
                } else {
                  writingColumn
                  reviewColumn
                }
              }.padding(.vertical, 32)
            }
          }
          .onChange(of: studio.captureNonce, initial: true) {
            guard studio.captureHint.hasSuffix("dashboard-activity") else { return }
            DispatchQueue.main.async { scroll.scrollTo("world-activity", anchor: .bottom) }
          }
        }
      }
    }
    .task(id: "\(studio.worldID):\(studio.worldRevision)") { refresh() }
  }
  private var welcome: some View {
    HStack(spacing: 20) {
      if let cover = studio.worldCover {
        Image(nsImage: cover).resizable().scaledToFill().frame(width: 72, height: 72)
          .clipShape(RoundedRectangle(cornerRadius: Metric.floatingRadius))
          .accessibilityLabel("\(studio.world?.name ?? "World") artwork")
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("Welcome back").font(.studio(.label)).foregroundStyle(t.secondary)
        Text(studio.world?.name ?? "Your universe").font(.studio(.entityTitle)).lineLimit(2)
          .accessibilityAddTraits(.isHeader)
        Text(
          studio.world?.description.isEmpty == false
            ? studio.world!.description : "Pick up a thread, or begin something new."
        ).font(.studio(.body)).foregroundStyle(t.secondary).lineLimit(2)
      }
      Spacer(minLength: 0)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private var writingColumn: some View {
    VStack(alignment: .leading, spacing: 28) {
      group("Recently edited entities", action: "Library", run: { studio.navigate(.library) }) {
        if studio.dashboardEntities.isEmpty {
          empty("Characters, places and systems will appear here as you create them.")
          Button("Create entity") {
            studio.newRecordKind = "entity"
            studio.sheet = .document
          }.buttonStyle(QuietButton(t: t))
        } else {
          ForEach(studio.dashboardEntities.prefix(4)) { recordRow($0) }
        }
      }
      group("Unfinished writing") {
        if studio.dashboardWriting.isEmpty {
          empty("No loose ideas or unfinished documents. New drafts appear here automatically.")
        } else {
          ForEach(studio.dashboardWriting.prefix(3)) { recordRow($0) }
        }
      }
    }
  }
  private var reviewColumn: some View {
    VStack(alignment: .leading, spacing: 28) {
      group("Projects", action: "All projects", run: { studio.openLens("Projects") }) {
        if studio.dashboardProjects.isEmpty {
          empty("Keep a story, campaign or creative plan together in a project outline.")
          Button("Start a project") { studio.sheet = .project }.buttonStyle(QuietButton(t: t))
        } else {
          ForEach(studio.dashboardProjects.prefix(3)) { recordRow($0, compact: true) }
        }
      }
      group("Open proposals", action: "Review", run: { studio.navigate(.review) }) {
        if studio.pendingProposals.isEmpty {
          empty("Nothing awaiting a decision. Your existing canon stays as you left it.")
        } else {
          ForEach(studio.pendingProposals.prefix(3)) { proposal in
            Button {
              studio.openProposalReview(proposal.id)
            } label: {
              VStack(alignment: .leading, spacing: 6) {
                Text(proposal.summary.isEmpty ? "Proposed changes" : proposal.summary)
                  .font(.studio(.control)).foregroundStyle(t.text).lineLimit(2)
                Text(
                  "\(proposal.pending) \(proposal.pending == 1 ? "change" : "changes") to review"
                )
                .font(.studio(.caption)).foregroundStyle(t.secondary)
              }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
                .hoverFill(t)
            }.buttonStyle(.plain)
          }
        }
      }
      activitySection.id("world-activity")
    }
  }
  private var activitySection: some View {
    group("World activity", action: "View history") {
      studio.sheet = .activity
    } content: {
      if let failure {
        HStack {
          Text(failure).font(.studio(.label)).foregroundStyle(t.danger)
          Button("Retry", action: refresh).buttonStyle(QuietButton(t: t))
        }
      } else if activity.isEmpty {
        empty("Saved edits, relationships, maps and history will appear here.")
      } else {
        ForEach(activity.prefix(4)) { item in
          Button {
            studio.openActivity(item)
          } label: {
            HStack(spacing: 12) {
              StudioIcon(activityIcon(item.kind), size: 16).foregroundStyle(t.secondary)
                .frame(width: 24)
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title.isEmpty ? "Proposed changes" : item.title)
                  .font(.studio(.control)).foregroundStyle(t.text).lineLimit(1)
                Text(item.detail).font(.studio(.caption)).foregroundStyle(t.secondary).lineLimit(1)
              }
              Spacer(minLength: 12)
              Text(relativeDate(item.updatedAt)).font(.studio(.caption)).foregroundStyle(t.muted)
            }.padding(.horizontal, 8).padding(.vertical, 8).contentShape(Rectangle()).hoverFill(t)
          }.buttonStyle(.plain)
        }
        Text("Latest saved change for each object.").font(.studio(.caption)).foregroundStyle(
          t.muted)
      }
    }
  }
  private func group<Content: View>(
    _ title: String, action: String? = nil, run: @escaping () -> Void = {},
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title).font(.studio(.control)).foregroundStyle(t.secondary)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let action {
          Button(action, action: run).font(.studio(.caption)).buttonStyle(
            QuietButton(t: t, role: .ghost))
        }
      }.padding(.bottom, 4)
      content()
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func empty(_ text: String) -> some View {
    Text(text).font(.studio(.label)).foregroundStyle(t.secondary)
      .fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
  }
  private func recordRow(_ record: LoreRecord, compact: Bool = false) -> some View {
    Button {
      studio.openRecord(record)
    } label: {
      HStack(alignment: .top, spacing: 12) {
        CategoryTile(record: record, t: t)
        VStack(alignment: .leading, spacing: 5) {
          Text(record.title).font(.studio(.cardTitle)).foregroundStyle(t.text).lineLimit(1)
          if !compact && !record.body.isEmpty {
            Text(record.body.replacingOccurrences(of: "\n", with: " "))
              .font(.studio(.label)).foregroundStyle(t.secondary).lineLimit(1)
          }
          Text(
            [
              record.category.isEmpty ? Vocabulary.kindLabel(record.kind) : record.category,
              relativeDate(record.updatedAt),
            ].filter { !$0.isEmpty }.joined(separator: " · ")
          ).font(.studio(.caption)).foregroundStyle(t.muted).lineLimit(1)
        }
        Spacer(minLength: 0)
      }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()).hoverFill(t)
    }.buttonStyle(.plain).help("Open \(record.title)")
  }
  private func activityIcon(_ kind: WorldActivity.Kind) -> String {
    switch kind {
    case .world: "globe"
    case .conversation: "bubble.left"
    case .record: "doc.text"
    case .relationship: Destination.knowledge.icon
    case .event, .lane: Destination.timeline.icon
    case .board: "rectangle.on.rectangle"
    case .proposal: Destination.review.icon
    }
  }
  private func refresh() {
    do {
      activity = try studio.store.recentWorldActivity(worldID: studio.worldID)
      failure = nil
    } catch {
      activity = []
      failure = error.localizedDescription
    }
  }
}

struct NewProjectSheet: View {
  @ObservedObject var studio: Studio
  @State private var name = ""
  private func close() { studio.sheet = nil }
  var body: some View {
    SheetScaffold(
      title: "New project", subtitle: "An outline for a story, campaign or creative plan.",
      t: studio.t, width: 480, close: close
    ) {
      FormField(label: "Project name", placeholder: "The first crossing", text: $name, t: studio.t)
      {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          studio.createProject(name)
        }
      }
      Text("Write freely, add sections and link existing lore. It saves in your world as a draft.")
        .font(.studio(.label)).foregroundStyle(studio.t.secondary)
    } footer: {
      Spacer()
      Button("Cancel") { studio.sheet = nil }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create project") { studio.createProject(name) }
        .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
}
