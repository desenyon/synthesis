import SwiftUI
import SynthesisCore

/// Mechanics, scenarios and explicit rule review share the core rule model.
struct RulesLab: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  @State private var rules: [WorldRule] = []
  @State private var scenarios: [RuleScenario] = []
  @State private var findings: [RuleFinding] = []
  @State private var filter: WorldRule.Kind?
  @State private var editing: WorldRule?
  @State private var initialKind: WorldRule.Kind = .cost
  @State private var ruleForm = false
  @State private var scenarioForm = false
  @State private var editingScenario: RuleScenario?
  @State private var historyRule: WorldRule?
  @State private var review: WorldRule?
  var body: some View {
    ScrollView {
      ContentColumn {
        VStack(alignment: .leading, spacing: 24) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
              Text("How this world works").font(.studio(size: 28, weight: .semibold)).tracking(-0.5)
              Text("Define the mechanics. Explore their limits. Keep the exceptions deliberate.")
                .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
            }
            Spacer()
            Button("Add rule") {
              editing = nil
              initialKind = filter ?? .cost
              ruleForm = true
            }
            .buttonStyle(QuietButton(t: studio.t, primary: true))
          }
          ScrollView(.horizontal) {
            HStack(spacing: 6) {
              FilterChip(title: "All", count: rules.count, selected: filter == nil, t: studio.t) {
                filter = nil
              }
              ForEach(WorldRule.Kind.allCases, id: \.self) { kind in
                FilterChip(title: kind.title, selected: filter == kind, t: studio.t) {
                  filter = kind
                }
              }
            }
          }.scrollIndicators(.never)
          if rules.isEmpty {
            Text(
              "No mechanics have been established. Start with a source, a cost, a limit — or a technique you want to explore."
            )
            .font(.studio(size: 15)).foregroundStyle(studio.t.secondary).lineSpacing(4).padding(
              .vertical, 20)
          } else {
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], alignment: .leading,
              spacing: 14
            ) {
              ForEach(rules.filter { filter == nil || $0.kind == filter }) { rule in ruleCard(rule)
              }
            }
          }
          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Text("Scenarios").font(.studio(size: 20, weight: .semibold))
              Spacer()
              Button("Add scenario") {
                editingScenario = nil
                scenarioForm = true
              }
              .buttonStyle(QuietButton(t: studio.t))
            }
            Text(
              "Describe a situation and record your own conclusion. These are creative tests, not automatic simulations."
            )
            .font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
            ForEach(scenarios) { scenario in
              VStack(alignment: .leading, spacing: 9) {
                HStack {
                  Text(scenario.title).font(.studio(size: 16, weight: .semibold)).lineLimit(2)
                  Spacer()
                  Text(
                    scenario.expectation == "unclear"
                      ? "Open question" : "Expected: \(scenario.expectation)"
                  )
                  .font(.studio(size: 12)).foregroundStyle(studio.t.secondary)
                  IconButton(icon: "pencil.line", label: "Edit scenario", t: studio.t) {
                    editingScenario = scenario
                    scenarioForm = true
                  }
                  IconButton(icon: "minus.circle", label: "Remove scenario", t: studio.t) {
                    removeScenario(scenario)
                  }
                }
                Text(scenario.situation).font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
                  .lineSpacing(3)
                if !scenario.verdict.isEmpty {
                  Text(scenario.verdict).font(.studio(size: 14)).padding(12).frame(
                    maxWidth: .infinity, alignment: .leading
                  )
                  .background(studio.t.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                }
              }.padding(18).background(studio.t.surface, in: RoundedRectangle(cornerRadius: 14))
            }
          }
          DisclosureGroup {
            Text(
              "Local structure checks only. These do not determine whether your lore is consistent or true."
            )
            .font(.studio(size: 12)).foregroundStyle(studio.t.secondary).padding(.vertical, 8)
            ForEach(findings) { finding in
              VStack(alignment: .leading, spacing: 5) {
                Text(finding.title).font(.studio(size: 14, weight: .medium))
                Text(finding.detail).font(.studio(size: 13)).foregroundStyle(studio.t.secondary)
              }.padding(.vertical, 5)
            }
          } label: {
            Text("Open considerations · \(findings.count)").font(.studio(size: 14, weight: .medium))
          }.tint(studio.t.secondary)
        }.padding(.vertical, 28)
      }
    }
    .onAppear {
      load()
      if studio.captureHint == "mechanics-scenario" { scenarioForm = true }
      if studio.captureHint == "mechanics-history" {
        historyRule = rules.first { $0.kind == .cost }
      }
      if studio.captureHint == "mechanics-review" { review = rules.first { $0.kind == .cost } }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
    .studioSheet(isPresented: $ruleForm) {
      RecordRuleEditor(studio: studio, record: record, existing: editing, initialKind: initialKind)
      { ruleForm = false }
    }
    .studioSheet(isPresented: $scenarioForm) {
      ScenarioEditor(studio: studio, record: record, existing: editingScenario) {
        scenarioForm = false
      }
    }
    .studioSheet(item: $historyRule) { rule in
      RuleHistorySheet(studio: studio, rule: rule) { historyRule = nil }
    }
    .studioSheet(item: $review) { rule in
      RuleCanonReview(studio: studio, rule: rule) { review = nil }
    }
  }
  private func ruleCard(_ rule: WorldRule) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(rule.kind.title).font(.studio(size: 12, weight: .medium)).foregroundStyle(
          studio.t.accent)
        Spacer()
        IconMenu(icon: "ellipsis", label: "Rule actions", t: studio.t) {
          Button("Edit draft") {
            editing = rule
            ruleForm = true
          }
          Button("Review for canon") { review = rule }.disabled(rule.state == "canon")
          Button("History") { historyRule = rule }
          Button("Remove rule") { removeRule(rule) }
        }
      }
      Text(rule.title).font(.studio(size: 17, weight: .semibold)).lineLimit(3)
      Text(rule.body).font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
      StateBadge(state: rule.state, t: studio.t)
    }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(studio.t.surface, in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(studio.t.hairline, lineWidth: 1))
  }
  private func load() {
    studio.perform {
      rules = try studio.store.rules(worldID: record.worldID, systemID: record.id)
      scenarios = try studio.store.scenarios(worldID: record.worldID, systemID: record.id)
      findings = try studio.store.ruleChecks(worldID: record.worldID, systemID: record.id)
    }
  }
  private func removeRule(_ rule: WorldRule) {
    studio.perform {
      try studio.store.setRuleArchived(worldID: record.worldID, id: rule.id, archived: true)
      try studio.reload()
      studio.show("Removed rule", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setRuleArchived(worldID: record.worldID, id: rule.id, archived: false)
          try studio.reload()
        }
      }
    }
  }
  private func removeScenario(_ scenario: RuleScenario) {
    studio.perform {
      try studio.store.setScenarioArchived(worldID: record.worldID, id: scenario.id, archived: true)
      try studio.reload()
      studio.show("Removed scenario", actionTitle: "Undo") {
        studio.perform {
          try studio.store.setScenarioArchived(
            worldID: record.worldID, id: scenario.id, archived: false)
          try studio.reload()
        }
      }
    }
  }
}

private struct ScenarioEditor: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  let existing: RuleScenario?
  var close: () -> Void
  @State private var title = ""
  @State private var situation = ""
  @State private var expectation = "unclear"
  @State private var verdict = ""
  @State private var error: String?
  var body: some View {
    SheetScaffold(
      title: existing == nil ? "New scenario" : "Edit scenario", subtitle: record.title,
      t: studio.t, width: 540, close: close
    ) {
      FormField(label: "Title", placeholder: "A situation to explore", text: $title, t: studio.t)
      FormTextArea(
        label: "Situation", placeholder: "What happens, and under which assumptions?",
        text: $situation, t: studio.t, height: 90)
      ChoiceField(
        title: "Expected outcome", selection: $expectation,
        choices: [
          ("unclear", "Open question"), ("works", "Should work"), ("fails", "Should fail"),
        ], t: studio.t)
      FormTextArea(
        label: "Your conclusion",
        placeholder: "Optional. Record your reasoning when you are ready.", text: $verdict,
        t: studio.t, height: 80)
      if let error { Text(error).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Save scenario") { save() }.buttonStyle(QuietButton(t: studio.t, primary: true))
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }.onAppear {
      title = existing?.title ?? ""
      situation = existing?.situation ?? ""
      expectation = existing?.expectation ?? "unclear"
      verdict = existing?.verdict ?? ""
    }
  }
  private func save() {
    do {
      if let existing {
        guard
          try studio.store.scenarios(worldID: record.worldID, systemID: record.id).first(where: {
            $0.id == existing.id
          }) == existing
        else { throw SynthesisError.stale }
      }
      _ = try studio.store.saveScenario(
        worldID: record.worldID, systemID: record.id, id: existing?.id, title: title,
        situation: situation, expectation: expectation, verdict: verdict)
      try studio.reload()
      close()
    } catch { self.error = error.localizedDescription }
  }
}

private struct RuleCanonReview: View {
  @ObservedObject var studio: Studio
  let rule: WorldRule
  var close: () -> Void
  @State private var error: String?
  var body: some View {
    SheetScaffold(
      title: "Review rule for canon", subtitle: rule.title, t: studio.t, width: 560, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Accepted wording").font(.studio(size: 12, weight: .medium)).foregroundStyle(
            studio.t.secondary)
          Text(rule.accepted.map { "\($0.title)\n\($0.body)" } ?? "No accepted wording yet.").font(
            .studio(size: 14)
          ).textSelection(.enabled)
          Divider()
          Text("Proposed wording").font(.studio(size: 12, weight: .medium)).foregroundStyle(
            studio.t.accent)
          Text("\(rule.title)\n\(rule.body)").font(.studio(size: 14)).lineSpacing(4).textSelection(
            .enabled)
          Text("Only this rule will become canon. The entity and its other rules stay unchanged.")
            .font(.studio(size: 12)).foregroundStyle(studio.t.secondary)
        }
      }.frame(maxHeight: 300)
      if let error { Text(error).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
    } footer: {
      Spacer()
      Button("Keep as draft", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Accept this rule") {
        do {
          guard try studio.store.rule(worldID: rule.worldID, id: rule.id) == rule else {
            throw SynthesisError.stale
          }
          _ = try studio.store.promoteRule(
            worldID: rule.worldID, id: rule.id, confirmation: rule.id, expected: rule)
          try studio.reload()
          close()
        } catch { self.error = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true))
    }
  }
}

private struct RuleHistorySheet: View {
  @ObservedObject var studio: Studio
  let rule: WorldRule
  var close: () -> Void
  @State private var snapshots: [WorldRule] = []
  @State private var error: String?
  var body: some View {
    SheetScaffold(
      title: "Rule history", subtitle: rule.title, t: studio.t, width: 560, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if snapshots.isEmpty {
            Text("History begins with the next saved change to this rule.").font(.studio(size: 14))
              .foregroundStyle(studio.t.secondary)
          }
          ForEach(snapshots.indices, id: \.self) { index in
            let snapshot = snapshots[index]
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                StateBadge(state: snapshot.state, t: studio.t)
                Spacer()
                Text(snapshot.updatedAt).font(.studio(size: 11)).foregroundStyle(studio.t.secondary)
              }
              Text(snapshot.title).font(.studio(size: 15, weight: .semibold))
              Text(snapshot.body).font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
                .lineSpacing(3)
              if snapshot.title != rule.title || snapshot.body != rule.body
                || snapshot.kind != rule.kind
              {
                Button("Restore as draft") {
                  do {
                    _ = try studio.store.updateRule(
                      worldID: rule.worldID, id: rule.id, kind: snapshot.kind,
                      title: snapshot.title, body: snapshot.body, expected: rule)
                    try studio.reload()
                    close()
                  } catch { self.error = error.localizedDescription }
                }.buttonStyle(QuietButton(t: studio.t))
              }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(
              studio.t.surface, in: RoundedRectangle(cornerRadius: 12))
          }
        }
      }.frame(height: 350)
      if let error { Text(error).font(.studio(size: 13)).foregroundStyle(studio.t.danger) }
    } footer: {
      Text("Restoring preserves the accepted canon snapshot.").font(.studio(size: 12))
        .foregroundStyle(studio.t.secondary)
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t))
    }.onAppear {
      do { snapshots = try studio.store.ruleHistory(worldID: rule.worldID, id: rule.id) } catch {
        self.error = error.localizedDescription
      }
    }
  }
}
