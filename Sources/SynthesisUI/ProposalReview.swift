import SwiftUI
import SynthesisCore

/// Review surface for a staged AI change set. Every row is the creator's decision; accepting
/// produces drafts only, and canon keeps its own separate review.
struct ProposalCard: View {
  @ObservedObject var studio: Studio
  let proposal: Proposal
  var narrow = false
  @State private var expanded: Set<String> = []
  var body: some View {
    let t = studio.t
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 9) {
        StudioIcon("square.stack.3d.up", size: 13).foregroundStyle(t.accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("Proposed changes").font(.studio(size: 13.5, weight: .semibold))
          Text(proposal.summary).font(.studio(size: 13)).foregroundStyle(t.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Text(
          proposal.pending == 0
            ? "Reviewed" : "\(proposal.pending) to review"
        ).font(.studio(size: 12, weight: .medium)).fixedSize()
          .foregroundStyle(proposal.pending == 0 ? t.muted : t.accent)
      }.padding(.horizontal, 14).padding(.vertical, 12)
      ForEach(proposal.changes) { change in
        Rectangle().fill(t.hairline).frame(height: 1)
        row(change)
      }
      Rectangle().fill(t.hairline).frame(height: 1)
      // Side by side when there is room, stacked in the narrow companion.
      let layout =
        narrow
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        : AnyLayout(HStackLayout(spacing: 8))
      layout {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          StudioIcon("lock.shield", size: 11).foregroundStyle(t.muted)
          Text("Accepted changes are saved as drafts. Nothing becomes canon here.")
            .font(.studio(size: 12)).foregroundStyle(t.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !narrow { Spacer(minLength: 8) }
        if proposal.pending > 1 {
          HStack(spacing: 8) {
            Button("Dismiss all") { studio.resolveAll(proposal, accept: false) }
              .buttonStyle(QuietButton(t: t, role: .ghost))
            Button("Accept all as drafts") { studio.resolveAll(proposal, accept: true) }
              .buttonStyle(QuietButton(t: t))
          }
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 8)
    }
    .background(t.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Metric.cardRadius))
    .overlay(RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(t.hairline, lineWidth: 1))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Proposed changes: \(proposal.summary)")
    .disabled(studio.reviewingProposal)
  }
  private func describe(_ change: ProposedChange) -> (icon: String, kind: String, title: String) {
    switch change.action {
    case "create_record":
      return (
        categoryIcon(change.category ?? (change.kind == "capture" ? "ideas" : "")),
        "New \(Vocabulary.kindLabel(change.kind ?? "lore").lowercased())",
        change.title ?? "Untitled"
      )
    case "revise_record":
      return ("pencil.line", "Revise", studio.name(for: change.recordID, in: proposal))
    case "relate":
      return (
        "arrow.triangle.branch", "Relationship",
        "\(studio.name(for: change.source, in: proposal)) — \(change.label ?? "") → \(studio.name(for: change.target, in: proposal))"
      )
    case "create_branch", "create_period":
      return (
        "calendar", change.action == "create_branch" ? "New history branch" : "New period",
        ([change.title ?? "Untitled", change.date, change.endDate].compactMap { $0 }.filter {
          !$0.isEmpty
        }).joined(separator: " · ")
      )
    case "create_map":
      let parent = change.parentMapID.flatMap { id in
        (try? studio.store.boards(worldID: studio.worldID, kind: "atlas"))?.first { $0.id == id }?
          .name
      }
      let place = change.source.map { _ in studio.name(for: change.source, in: proposal) }
      return (
        "map", "New map · image chosen separately",
        ([change.title ?? "Map", place, parent.map { "Inside \($0)" }].compactMap { $0 }).joined(
          separator: " · ")
      )
    case "create_board": return ("rectangle.on.rectangle", "New canvas", change.title ?? "Board")
    case "place_record", "place_marker":
      return (
        change.action == "place_marker" ? "map" : "rectangle.on.rectangle",
        change.action == "place_marker" ? "Place on map" : "Place or move card",
        "\(studio.name(for: change.source, in: proposal)) → \(change.title ?? "Board") · (\(change.x ?? 0), \(change.y ?? 0))"
      )
    case "link_records":
      return (
        "link", "Link records",
        "\(studio.name(for: change.source, in: proposal)) → \(studio.name(for: change.target, in: proposal))"
      )
    case "create_component":
      return (
        "rectangle.on.rectangle",
        "\((change.kind ?? "notes").capitalized) · \((change.componentScope ?? "").capitalized)",
        change.title ?? "Component"
      )
    case "add_section":
      return (
        "doc.text", "Section of \(studio.name(for: change.source, in: proposal))",
        change.title ?? "Section"
      )
    case "revise_rule":
      return ("pencil.line", "Revise rule · \(change.kind ?? "")", change.title ?? "Rule")
    case "add_scenario":
      return ("lightbulb", "Scenario · \(change.kind ?? "unclear")", change.title ?? "Scenario")
    case "add_rule": return ("bolt", "New rule · \(change.kind ?? "")", change.title ?? "Rule")
    default:
      return (
        "calendar", "Event",
        "\(change.title ?? "Untitled") · \(change.date ?? "date unknown")"
      )
    }
  }
  private func laneName(_ id: String) -> String {
    if id.hasPrefix("change:") {
      return proposal.changes.first { "change:\($0.id)" == id }?.title ?? "New history"
    }
    return (try? studio.store.chronologyLanes(worldID: studio.worldID))?.first { $0.id == id }?.name
      ?? "History"
  }
  private func row(_ change: ProposedChange) -> some View {
    let t = studio.t
    let info = describe(change)
    let open = expanded.contains(change.id)
    let current = studio.records.first { $0.id == change.recordID }
    let detail = [
      "create_record", "create_component", "revise_record", "revise_rule", "add_rule",
      "add_scenario",
      "add_section",
      "create_branch", "create_period",
    ]
    .contains(change.action)
    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 10) {
        StudioIcon(info.icon, size: 12.5)
          .foregroundStyle(t.category(change.category ?? "")).frame(width: 18).padding(.top, 2)
        VStack(alignment: .leading, spacing: 3) {
          Text(info.kind).font(.studio(size: 11.5, weight: .medium)).foregroundStyle(t.muted)
          Text(info.title).font(.studio(size: 14, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
          if let lane = change.laneID {
            Text("Inside \(laneName(lane))").font(.studio(size: 12.5)).foregroundStyle(t.secondary)
          }
          if change.action == "add_event", change.source == nil {
            Text("Creates a linked draft source document").font(.studio(size: 12)).foregroundStyle(
              t.secondary)
          }
          if let reason = change.reason {
            Text(reason).font(.studio(size: 12.5)).foregroundStyle(t.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          if change.action == "revise_record", let current,
            current.version != change.baseVersion, change.status == "pending"
          {
            StudioLabel(
              "This record changed after the proposal was made.",
              icon: "exclamationmark.triangle"
            )
            .font(.studio(size: 12)).foregroundStyle(t.warning)
          }
          if detail, let text = change.body, !text.isEmpty {
            Button {
              if open { expanded.remove(change.id) } else { expanded.insert(change.id) }
            } label: {
              HStack(spacing: 4) {
                StudioIcon(open ? "chevron.down" : "chevron.right")
                  .font(.studio(size: 8, weight: .bold))
                Text(
                  open
                    ? "Hide"
                    : (["revise_record", "revise_rule"].contains(change.action)
                      ? "Show what changes" : "Show text")
                ).font(.studio(size: 12, weight: .medium))
              }.foregroundStyle(t.accent)
            }.buttonStyle(.plain)
          }
        }
        Spacer(minLength: 8)
        if !narrow { status(change) }
      }
      if narrow { status(change).padding(.leading, 28) }
      if open, let text = change.body {
        preview(
          text,
          against: change.action == "revise_rule"
            ? change.ruleBefore?.body : (change.action == "revise_record" ? current?.body : nil)
        )
        .padding(.leading, 28)
      }
      if !change.evidence.isEmpty {
        FlowLayout(spacing: 6) {
          Text("Based on").font(.studio(size: 11.5)).foregroundStyle(t.muted)
            .frame(height: 22)
          ForEach(change.evidence, id: \.self) { id in
            if let record = studio.records.first(where: { $0.id == id }) {
              Button {
                studio.openRecord(record)
              } label: {
                StudioLabel(record.title, icon: recordIcon(record))
                  .font(.studio(size: 11.5, weight: .medium)).lineLimit(1)
                  .foregroundStyle(t.secondary).padding(.horizontal, 7).frame(height: 22)
                  .background(t.background.opacity(0.6), in: Capsule())
                  .overlay(Capsule().stroke(t.hairline, lineWidth: 1))
              }.buttonStyle(.plain).help("Open \(record.title)")
            }
          }
        }.padding(.leading, 28)
      }
    }.padding(.horizontal, 14).padding(.vertical, 11)
      .opacity(change.status == "rejected" ? 0.55 : 1)
  }
  @ViewBuilder private func status(_ change: ProposedChange) -> some View {
    let t = studio.t
    switch change.status {
    case "accepted":
      HStack(spacing: 8) {
        StudioLabel("Saved", icon: "checkmark").font(.studio(size: 12, weight: .medium))
          .foregroundStyle(t.positive).fixedSize()
        if ["create_board", "place_record"].contains(change.action), let id = change.resultID {
          Button("Open canvas") {
            studio.canvasBoardID = id
            studio.navigate(.canvas)
          }.buttonStyle(QuietButton(t: t, role: .ghost))
        }
        if ["create_branch", "create_period", "add_event"].contains(change.action) {
          Button("Open timeline") { studio.navigate(.timeline) }.buttonStyle(
            QuietButton(t: t, role: .ghost))
        }
        if ["place_marker", "create_map"].contains(change.action), let id = change.resultID {
          Button("Open atlas") {
            studio.mapBoardID = id
            studio.navigate(.atlas)
          }.buttonStyle(QuietButton(t: t, role: .ghost))
        }
        let ruleSource =
          proposal.changes.first { "change:\($0.id)" == change.source }?.resultID ?? change.source
        if change.action == "add_rule",
          let record = studio.records.first(where: { $0.id == ruleSource })
        {
          Button("Open rules") {
            studio.inspector = true
            studio.openRecord(record)
          }.buttonStyle(QuietButton(t: t, role: .ghost))
        }
        if let record = studio.records.first(where: {
          $0.id == change.resultID && change.action != "relate" && change.action != "add_event"
        }) {
          Button("Open") { studio.openRecord(record) }
            .buttonStyle(QuietButton(t: t, role: .ghost))
        }
      }
    case "rejected":
      Text("Dismissed").font(.studio(size: 12, weight: .medium)).foregroundStyle(t.muted)
        .fixedSize()
    default:
      HStack(spacing: 6) {
        Button("Dismiss") {
          studio.resolve(proposal, change: change, accept: false)
        }.buttonStyle(QuietButton(t: t, role: .ghost))
        Button("Accept") { studio.resolve(proposal, change: change, accept: true) }
          .buttonStyle(QuietButton(t: t, primary: true))
          .help("Save this reviewed change")
          .disabled(
            change.action == "revise_record"
              && studio.records.first(where: { $0.id == change.recordID })?.version
                != change.baseVersion
          )
      }
    }
  }
  /// Full proposed text, or a line diff against the record as it is now.
  private func preview(_ text: String, against old: String?) -> some View {
    let t = studio.t
    let lines =
      old.map { TextDiff.lines(old: $0, new: text) }
      ?? text.components(separatedBy: "\n").map { TextDiff.Line(kind: .same, text: $0) }
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(lines.prefix(60).enumerated()), id: \.offset) { _, line in
        let tint: Color? =
          line.kind == .added ? t.positive : (line.kind == .removed ? t.danger : nil)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          if old != nil {
            Text(line.kind == .added ? "+" : (line.kind == .removed ? "−" : " "))
              .font(.studio(size: 12, weight: .semibold, design: .monospaced))
              .foregroundStyle(tint ?? .clear).frame(width: 10)
          }
          Text(line.text.isEmpty ? " " : line.text).font(.studio(size: 13)).lineSpacing(3)
            .foregroundStyle(line.kind == .same ? t.secondary : t.text)
            .strikethrough(line.kind == .removed, color: t.danger.opacity(0.6))
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 10).padding(.vertical, 2)
          .background((tint ?? .clear).opacity(tint == nil ? 0 : 0.12))
      }
      if lines.count > 60 {
        Text("… \(lines.count - 60) more lines").font(.studio(size: 12)).foregroundStyle(t.muted)
          .padding(.horizontal, 10).padding(.vertical, 4)
      }
    }.padding(.vertical, 6)
      .background(t.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.hairline, lineWidth: 1))
  }
}

/// Collapsed list of the records that were shared with the model for one answer.
struct ContextDisclosure: View {
  @ObservedObject var studio: Studio
  let sources: [ContextSource]
  @State private var open = false
  var body: some View {
    let t = studio.t
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(.easeOut(duration: 0.14)) { open.toggle() }
      } label: {
        HStack(spacing: 5) {
          HStack(spacing: -5) {
            ForEach(sources.prefix(3)) { source in
              StudioIcon(recordIcon(source.record), size: 10)
                .foregroundStyle(t.category(source.record.category))
                .frame(width: 22, height: 22).background(t.surface, in: Circle())
                .overlay(Circle().stroke(t.border, lineWidth: 1))
            }
          }.padding(.trailing, 4)
          Text("Used \(sources.count) lore \(sources.count == 1 ? "reference" : "references")")
            .font(.studio(size: 13, weight: .medium))
          StudioIcon("chevron.right", size: 10).rotationEffect(.degrees(open ? 90 : 0))
        }.foregroundStyle(t.secondary).padding(.horizontal, 8).frame(height: 26)
          .hoverFill(t, radius: 6)
      }.buttonStyle(.plain).padding(.leading, -8)
        .help("The world context that was shared with the model for this answer")
      if open {
        VStack(alignment: .leading, spacing: 1) {
          ForEach(sources) { source in
            Button {
              studio.openRecord(source.record)
            } label: {
              HStack(spacing: 8) {
                StudioIcon(recordIcon(source.record), size: 11.5)
                  .foregroundStyle(t.category(source.record.category)).frame(width: 16)
                Text(source.record.title).font(.studio(size: 13, weight: .medium)).lineLimit(1)
                Text(source.reason).font(.studio(size: 12)).foregroundStyle(t.muted)
                  .lineLimit(1)
                Spacer(minLength: 0)
                StateBadge(state: source.record.state, t: t)
              }.padding(.horizontal, 8).frame(height: 28).hoverFill(t, radius: 6)
            }.buttonStyle(.plain)
          }
        }.padding(6)
          .background(t.surface.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hairline, lineWidth: 1))
      }
    }
  }
}
