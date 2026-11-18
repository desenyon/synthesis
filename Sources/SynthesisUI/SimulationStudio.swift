import Foundation
import SwiftUI
import SynthesisCore

struct SimulationAssumptions {
  var replenishment = "0"
  var demand = "0"
  var pressure = "0"
  var variation = "0"

  init() {}

  init(_ value: SimulationResourceParameters) {
    replenishment = String(value.replenishment)
    demand = String(value.demand)
    pressure = String(value.pressure)
    variation = String(value.supplyVariation)
  }

  func parameters() throws -> SimulationResourceParameters {
    let range: ClosedRange<Int64> = 0...1_000_000_000
    guard let supply = Int64(replenishment), let demand = Int64(demand),
      let pressure = Int64(pressure), let variation = Int64(variation),
      [supply, demand, pressure, variation].allSatisfy(range.contains)
    else {
      throw SynthesisError.invalid(
        "Per-step amounts must be whole numbers between zero and one billion.")
    }
    return .init(
      replenishment: supply, demand: demand, pressure: pressure, supplyVariation: variation)
  }
}

struct SimulationRunForm {
  enum Horizon: String, CaseIterable, Identifiable {
    case hour = "Hour"
    case year = "Year"
    case century = "Century"
    case custom = "Custom"
    var id: Self { self }
  }

  var title = ""
  var unit = ""
  var horizon: Horizon = .custom
  var hours = "24"
  var hoursInYear = ""
  var stepHours = "1"
  var seed = "0"
  var stock = "0"
  var capacity = "100"
  var assumptions = SimulationAssumptions()

  func scenario() throws -> SimulationResourceScenario {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      title.unicodeScalars.count <= 120,
      !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      unit.unicodeScalars.count <= 40
    else {
      throw SynthesisError.invalid(
        "Give the run a name (up to 120 characters) and a unit (up to 40).")
    }
    guard let stepHours = Int64(stepHours), let seed = UInt64(seed),
      let stock = Int64(stock), let capacity = Int64(capacity)
    else { throw SynthesisError.invalid("Use whole numbers for the interval, amounts and seed.") }
    let duration: Int64
    switch horizon {
    case .hour:
      duration = 1
    case .year, .century:
      let years: Int64 = horizon == .year ? 1 : 100
      guard let hours = Int64(hoursInYear), hours > 0, hours <= Int64.max / years else {
        throw SynthesisError.invalid("Enter the number of hours in a year of this world.")
      }
      duration = hours * years
    case .custom:
      guard let hours = Int64(hours) else {
        throw SynthesisError.invalid("Enter the custom horizon in whole hours.")
      }
      duration = hours
    }
    return SimulationResourceScenario(
      horizonHours: duration, stepHours: stepHours, seed: seed, initialStock: stock,
      capacity: capacity, parameters: try assumptions.parameters())
  }
}

struct SimulationStudio: View {
  private enum Panel: String, CaseIterable, Identifiable {
    case setup = "Setup"
    case result = "Trace"
    case saved = "Saved runs"
    var id: Self { self }
  }

  @ObservedObject var studio: Studio
  let worldID: String
  @State private var panel: Panel = .setup
  @State private var form = SimulationRunForm()
  @State private var snapshot: SimulationResourceSnapshot?
  @State private var runTitle = ""
  @State private var runUnit = ""
  @State private var saved: SimulationRunSummary?
  @State private var entries: [SimulationRunSummary] = []
  @State private var showArchive = false
  @State private var error: String?
  @State private var assumptions = SimulationAssumptions()
  @State private var stockChange = ""
  @State private var showInterventions = false
  @State private var expandedHours = Set<Int64>()

  var body: some View {
    VStack(spacing: 0) {
      WorkspaceBar(studio: studio) {
        Text("Simulation").font(.studio(size: 15, weight: .semibold))
      } trailing: {
        EmptyView()
      }
      ScrollView {
        ContentColumn {
          VStack(alignment: .leading, spacing: Space.lg) {
            Picker("Simulation view", selection: $panel) {
              ForEach(Panel.allCases) { value in Text(value.rawValue).tag(value) }
            }.labelsHidden().pickerStyle(.segmented)
              .accessibilityLabel("Simulation view")
              .frame(maxWidth: 360, alignment: .leading)
            if let error {
              Text(error).font(.studio(.caption))
                .foregroundStyle(studio.t.warning).textSelection(.enabled)
            }
            switch panel {
            case .setup: setup
            case .result:
              if let snapshot {
                result(snapshot)
              } else {
                Text("Run a scenario from Setup to see its calculated trace.")
                  .font(.studio(.body)).foregroundStyle(studio.t.secondary)
              }
            case .saved: savedRuns
            }
          }.padding(.top, Space.md).padding(.bottom, Space.lg)
        }
      }
    }
    .onAppear { configureView() }
    .onChange(of: showArchive) { _, _ in perform { try refresh() } }
    .onChange(of: panel) { _, page in if page == .saved { perform { try refresh() } } }
  }

  private var setup: some View {
    VStack(alignment: .leading, spacing: Space.md) {
      Text("Resource balance").font(.studio(.title))
      Text("Calculate changes to one fictional reserve under assumptions you set.")
        .font(.studio(.body)).foregroundStyle(studio.t.secondary)
      fields {
        field("Run name", placeholder: "Winter stores", text: $form.title)
        field("Resource unit", placeholder: "Crates", text: $form.unit)
      }
      Picker("Horizon", selection: $form.horizon) {
        ForEach(SimulationRunForm.Horizon.allCases) { value in
          Text(value.rawValue).tag(value)
        }
      }.frame(maxWidth: 290, alignment: .leading)
      fields {
        switch form.horizon {
        case .hour: EmptyView()
        case .year, .century:
          field("Hours in this world’s year", placeholder: "Enter hours", text: $form.hoursInYear)
        case .custom:
          field("Duration in hours", placeholder: "24", text: $form.hours)
        }
        field("Hours per step", placeholder: "1", text: $form.stepHours)
        field("Seed", placeholder: "0", text: $form.seed)
      }
      Text("The horizon must divide into at most 10,000 equal steps.")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      fields {
        field("Starting stock", placeholder: "0", text: $form.stock)
        field("Storage capacity", placeholder: "100", text: $form.capacity)
      }
      assumptionFields($form.assumptions)
      Text(
        "Pressure reduces supply each step. Seeded variation adds or subtracts up to the amount you enter."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      HStack(spacing: Space.sm) {
        Button("Run scenario") { start(through: nil) }
          .buttonStyle(QuietButton(t: studio.t, primary: true))
        Button("Run first step") { start(through: 1) }
          .buttonStyle(QuietButton(t: studio.t))
      }
    }
  }

  private func result(_ snapshot: SimulationResourceSnapshot) -> some View {
    VStack(alignment: .leading, spacing: Space.md) {
      Text(runTitle).font(.studio(.title)).lineLimit(2)
      Text(snapshot.finished ? "Complete · Hypothetical result" : "Paused · Hypothetical result")
        .font(.studio(.captionStrong)).foregroundStyle(studio.t.accent)
      let closing = snapshot.trace.last?.closingStock ?? snapshot.scenario.initialStock
      let unmet = snapshot.trace.reduce(Int64(0)) { $0 + $1.unmetDemand }
      Text("\(closing) \(runUnit) remaining · \(unmet) unmet")
        .font(.studio(.section)).monospacedDigit()
      Text(
        "\(snapshot.trace.count) of \(snapshot.totalSteps) steps · \(snapshot.scenario.stepHours) hours per step · Seed \(snapshot.scenario.seed)"
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary).textSelection(.enabled)
      ViewThatFits(in: .horizontal) {
        HStack(spacing: Space.sm) { resultActions(snapshot) }
        VStack(alignment: .leading, spacing: Space.sm) { resultActions(snapshot) }
      }
      if !snapshot.finished {
        interventions(snapshot)
      }
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      Text("Step-by-step trace").font(.studio(.section))
      LazyVStack(alignment: .leading, spacing: Space.sm) {
        ForEach(snapshot.trace, id: \.hour) { step in stepDetail(step) }
      }
    }
  }

  @ViewBuilder private func resultActions(_ snapshot: SimulationResourceSnapshot) -> some View {
    if !snapshot.finished {
      Button("Run next step") {
        advance(snapshot, through: snapshot.trace.count + 1)
      }.buttonStyle(QuietButton(t: studio.t, primary: true))
      Button("Finish run") { advance(snapshot, through: snapshot.totalSteps) }
        .buttonStyle(QuietButton(t: studio.t))
    }
    Button("Replay trace") {
      perform {
        guard try snapshot.replayed() == snapshot else {
          throw SynthesisError.invalid("Replay does not match this saved trace.")
        }
        studio.show("Replay matched all \(snapshot.trace.count) steps")
      }
    }.buttonStyle(QuietButton(t: studio.t))
    if saved == nil {
      Button("Save run") { saveRun(snapshot) }.buttonStyle(QuietButton(t: studio.t))
    } else {
      Text(saved?.archived == true ? "Archived" : "Saved").font(.studio(.captionStrong))
        .foregroundStyle(studio.t.secondary)
    }
  }

  private func interventions(_ snapshot: SimulationResourceSnapshot) -> some View {
    DisclosureGroup("Change the next step", isExpanded: $showInterventions) {
      VStack(alignment: .leading, spacing: Space.sm) {
        let next = snapshot.trace.count + 1
        let actions = snapshot.scenario.interventions.filter { $0.step == next }.map(\.action)
        if !actions.isEmpty {
          Text("Scheduled for step \(next)")
            .font(.studio(.captionStrong))
          Text(actions.map(actionLabel).joined(separator: " · "))
            .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
        }
        assumptionFields($assumptions)
        Button("Schedule new assumptions") {
          perform {
            try add(.setParameters(assumptions.parameters()), to: snapshot)
          }
        }.buttonStyle(QuietButton(t: studio.t))
        field("Stock change", placeholder: "Positive delivery or negative loss", text: $stockChange)
        Button("Schedule stock change") {
          perform {
            guard let amount = Int64(stockChange) else {
              throw SynthesisError.invalid("Enter a whole-number stock change.")
            }
            try add(.adjustStock(amount), to: snapshot)
            stockChange = ""
          }
        }.buttonStyle(QuietButton(t: studio.t))
      }.padding(.top, Space.sm)
    }
  }

  private func stepDetail(_ step: SimulationResourceStep) -> some View {
    DisclosureGroup(
      isExpanded: Binding(
        get: { expandedHours.contains(step.hour) },
        set: { expanded in
          if expanded {
            _ = expandedHours.insert(step.hour)
          } else {
            _ = expandedHours.remove(step.hour)
          }
        })
    ) {
      VStack(alignment: .leading, spacing: Space.xs) {
        Text(
          "Opening \(step.openingStock) · Stock change \(step.stockAdjustment) · Closing \(step.closingStock)"
        )
        Text(
          "Supply \(step.parameters.replenishment) · Pressure −\(step.parameters.pressure) · Seeded variation \(step.supplyVariation) · Actual supply \(step.replenishment)"
        )
        Text(
          "Demand \(step.parameters.demand) · Used \(step.consumed) · Unmet \(step.unmetDemand) · Surplus discarded \(step.discarded)"
        )
        if !step.actions.isEmpty {
          Text(step.actions.map(actionLabel).joined(separator: " · "))
        }
      }.font(.studio(.caption)).foregroundStyle(studio.t.secondary)
        .padding(.vertical, Space.xs).textSelection(.enabled)
    } label: {
      Text("Hour \(step.hour) · \(step.closingStock) \(runUnit) · \(step.unmetDemand) unmet")
        .font(.studio(.body)).monospacedDigit()
    }
  }

  private func actionLabel(_ action: SimulationResourceAction) -> String {
    switch action {
    case .adjustStock(let amount):
      return "Scheduled stock change \(amount)"
    case .setParameters(let parameters):
      return
        "New assumptions · Supply \(parameters.replenishment) · Demand \(parameters.demand) · Pressure \(parameters.pressure) · Variation \(parameters.supplyVariation)"
    }
  }

  private var savedRuns: some View {
    VStack(alignment: .leading, spacing: Space.md) {
      Text("Saved runs").font(.studio(.title))
      Toggle("Show archived runs", isOn: $showArchive)
      if entries.isEmpty {
        Text(showArchive ? "No archived runs." : "Save a calculated trace to reopen it here.")
          .font(.studio(.body)).foregroundStyle(studio.t.secondary)
      }
      LazyVStack(alignment: .leading, spacing: Space.sm) {
        ForEach(entries) { entry in
          HStack(spacing: Space.sm) {
            Button {
              reopen(entry.id)
            } label: {
              VStack(alignment: .leading, spacing: Space.xs) {
                Text(entry.title).font(.studio(.body)).lineLimit(1)
                Text("\(entry.completedSteps) of \(entry.totalSteps) steps · \(entry.unit)")
                  .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(1)
              }.frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Open saved simulation trace")
            Button(entry.archived ? "Restore" : "Archive") { archive(entry) }
              .buttonStyle(QuietButton(t: studio.t))
          }.padding(.vertical, Space.xs)
          Rectangle().fill(studio.t.hairline).frame(height: 1)
        }
      }
    }
  }

  private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      Text(label).font(.studio(.captionStrong))
      FormField(placeholder: placeholder, text: text, t: studio.t).accessibilityLabel(label)
    }.frame(minWidth: 125, maxWidth: .infinity, alignment: .leading)
  }

  private func fields<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: Space.sm, content: content)
      VStack(alignment: .leading, spacing: Space.sm, content: content)
    }
  }

  private func assumptionFields(_ draft: Binding<SimulationAssumptions>) -> some View {
    VStack(spacing: Space.sm) {
      fields {
        field("Replenishment per step", placeholder: "0", text: draft.replenishment)
        field("Demand per step", placeholder: "0", text: draft.demand)
      }
      fields {
        field("Environmental pressure", placeholder: "0", text: draft.pressure)
        field("Supply variation", placeholder: "0", text: draft.variation)
      }
    }
  }

  private func perform(_ operation: () throws -> Void) {
    guard studio.worldID == worldID else { return }
    do {
      error = nil
      try operation()
    } catch {
      self.error = error.localizedDescription
    }
  }

  private func configureView() {
    guard !studio.captureHint.isEmpty,
      Studio.simulationCaptureStates.contains(studio.captureHint)
    else { return }
    form.title = "Winter supply at the crossing"
    form.unit = "crates"
    form.hours = "144"
    form.stepHours = "24"
    form.seed = "11"
    form.stock = "30"
    form.capacity = "50"
    form.assumptions = .init(.init(replenishment: 10, demand: 12, pressure: 5))
    switch studio.captureHint {
    case "simulation-trace":
      start(through: nil)
      if let hour = snapshot?.trace.first?.hour { expandedHours.insert(hour) }
    case "simulation-paused":
      start(through: 3)
      if let snapshot { perform { try add(.adjustStock(8), to: snapshot) } }
      showInterventions = true
    case "simulation-saved":
      perform { try refresh() }
      panel = .saved
    default: break
    }
  }

  private func start(through count: Int?) {
    perform {
      let next = try SimulationResourceSnapshot(scenario: form.scenario(), through: count)
      runTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
      runUnit = form.unit.trimmingCharacters(in: .whitespacesAndNewlines)
      saved = nil
      snapshot = next
      assumptions = .init(next.trace.last?.parameters ?? next.scenario.parameters)
      stockChange = ""
      showInterventions = false
      expandedHours.removeAll()
      panel = .result
    }
  }

  private func advance(_ current: SimulationResourceSnapshot, through count: Int) {
    perform {
      let next = try current.replayed(through: count)
      saved = nil
      snapshot = next
      if let latest = next.trace.last { assumptions = .init(latest.parameters) }
    }
  }

  private func add(_ action: SimulationResourceAction, to current: SimulationResourceSnapshot)
    throws
  {
    let next = try current.adding([action])
    saved = nil
    snapshot = next
  }

  private func saveRun(_ snapshot: SimulationResourceSnapshot) {
    perform {
      let run = try studio.store.saveSimulationRun(
        worldID: worldID, title: runTitle, unit: runUnit, snapshot: snapshot)
      saved = run.summary
      studio.show("Saved simulation run")
    }
  }

  private func refresh() throws {
    entries = try studio.store.simulationRuns(worldID: worldID, archived: showArchive)
  }

  private func reopen(_ id: String) {
    perform {
      let run = try studio.store.simulationRun(worldID: worldID, id: id)
      snapshot = run.snapshot
      saved = run.summary
      runTitle = run.summary.title
      runUnit = run.summary.unit
      assumptions = .init(run.snapshot.trace.last?.parameters ?? run.snapshot.scenario.parameters)
      stockChange = ""
      showInterventions = false
      expandedHours.removeAll()
      panel = .result
    }
  }

  private func archive(_ entry: SimulationRunSummary) {
    perform {
      let changed = try studio.store.setSimulationRunArchived(
        worldID: worldID, id: entry.id, archived: !entry.archived, expectedRevision: entry.revision)
      if saved?.id == changed.id { saved = changed }
      if changed.archived {
        studio.show("Archived “\(entry.title)”", icon: "archivebox", actionTitle: "Undo") {
          studio.perform {
            let restored = try studio.store.setSimulationRunArchived(
              worldID: worldID, id: changed.id, archived: false, expectedRevision: changed.revision)
            if studio.worldID == worldID {
              if saved?.id == restored.id { saved = restored }
              try refresh()
            }
          }
        }
      } else {
        studio.show("Restored “\(entry.title)”")
      }
      try refresh()
    }
  }
}

extension Studio {
  static let simulationCaptureStates = [
    "simulation-setup", "simulation-trace", "simulation-paused", "simulation-saved",
  ]

  func configureSimulationCapture(_ state: String, board: String, conversation: String) {
    guard ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] != nil else { return }
    configureConnectedCapture("library", board: board, conversation: conversation)
    setMode(.manual)
    navigate(.simulation)
    captureHint = state
    guard state == "simulation-saved" else { return }
    perform {
      let title = "Winter supply at the crossing"
      let existing = try store.simulationRuns(worldID: worldID)
      guard !existing.contains(where: { $0.title == title }) else { return }
      let scenario = SimulationResourceScenario(
        horizonHours: 144, stepHours: 24, seed: 11, initialStock: 30, capacity: 50,
        parameters: .init(replenishment: 10, demand: 12, pressure: 5))
      try store.saveSimulationRun(
        worldID: worldID, title: title, unit: "crates", snapshot: .init(scenario: scenario))
    }
  }
}
