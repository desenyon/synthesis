import SwiftUI
import SynthesisCore

/// Techniques and progression steps of one system, laid out top to bottom by what each requires.
/// The layout is derived from stored prerequisites; it is never saved and never invents edges.
struct TechniqueTreeView: View {
  @ObservedObject var studio: Studio
  let rules: [WorldRule]
  let edges: [RulePrerequisite]
  var open: (WorldRule) -> Void
  private static let card = CGSize(width: 230, height: 92)
  var body: some View {
    let nodes = rules.filter { WorkspaceStore.treeKinds.contains($0.kind) }
    let ids = Set(nodes.map(\.id))
    let live = edges.filter { ids.contains($0.ruleID) && ids.contains($0.requiresID) }
    // Dagre places each requirement above what it unlocks.
    let points = GraphLayout.positions(
      nodes: nodes.map(\.id), edges: live.map { ($0.requiresID, $0.ruleID) }, landscape: false,
      size: Self.card, nodeSeparation: 28, rankSeparation: 56)
    let xs = points.values.map(\.x)
    let ys = points.values.map(\.y)
    let size = CGSize(
      width: (xs.max() ?? 0) - (xs.min() ?? 0) + Self.card.width + 24,
      height: (ys.max() ?? 0) - (ys.min() ?? 0) + Self.card.height + 24)
    let origin = CGPoint(
      x: (xs.min() ?? 0) - Self.card.width / 2 - 12, y: (ys.min() ?? 0) - Self.card.height / 2 - 12)
    GeometryReader { geo in
      let scale = min(1, geo.size.width / max(size.width, 1))
      ZStack(alignment: .topLeading) {
        Canvas { context, _ in
          for edge in live {
            guard let a = points[edge.requiresID], let b = points[edge.ruleID] else { continue }
            let start = CGPoint(x: a.x - origin.x, y: a.y - origin.y + Self.card.height / 2)
            let end = CGPoint(x: b.x - origin.x, y: b.y - origin.y - Self.card.height / 2)
            var path = Path()
            path.move(to: start)
            let middle = (start.y + end.y) / 2
            path.addCurve(
              to: end, control1: CGPoint(x: start.x, y: middle),
              control2: CGPoint(x: end.x, y: middle))
            context.stroke(path, with: .color(studio.t.accent.opacity(0.7)), lineWidth: 1.5)
            var head = Path()
            head.move(to: CGPoint(x: end.x - 5, y: end.y - 7))
            head.addLine(to: end)
            head.addLine(to: CGPoint(x: end.x + 5, y: end.y - 7))
            context.stroke(head, with: .color(studio.t.accent.opacity(0.7)), lineWidth: 1.5)
          }
        }.frame(width: size.width, height: size.height)
        ForEach(nodes) { rule in
          if let point = points[rule.id] {
            node(rule, requiredBy: live.filter { $0.requiresID == rule.id }.count)
              .position(x: point.x - origin.x, y: point.y - origin.y)
          }
        }
      }.frame(width: size.width, height: size.height)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
    }.frame(height: size.height * min(1, 840 / max(size.width, 1)))
      .accessibilityElement(children: .contain).accessibilityLabel("Technique tree")
  }
  private func node(_ rule: WorldRule, requiredBy: Int) -> some View {
    Button {
      open(rule)
    } label: {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text(rule.kind == .technique ? "Technique" : "Step")
            .font(.studio(size: 11, weight: .medium)).foregroundStyle(studio.t.accent)
          Spacer(minLength: 4)
          if rule.state == "canon" { StateBadge(state: "canon", t: studio.t) }
        }
        Text(rule.title).font(.studio(size: 14, weight: .semibold)).lineLimit(2)
          .multilineTextAlignment(.leading)
        if requiredBy > 0 {
          Text("Unlocks \(requiredBy)").font(.studio(size: 11.5)).foregroundStyle(studio.t.muted)
        }
      }.padding(12).frame(
        width: Self.card.width, height: Self.card.height, alignment: .topLeading
      )
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: Metric.cardRadius).stroke(studio.t.hairline, lineWidth: 1))
    }.buttonStyle(.plain).help("Edit \(rule.title)")
      .accessibilityLabel("\(rule.title), \(rule.kind.singular)")
  }
}
