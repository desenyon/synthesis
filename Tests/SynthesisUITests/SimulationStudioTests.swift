import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct SimulationStudioTests {
  @Test func commandPaletteOpensSimulationInManualModeWithNoProviderRequest() throws {
    let studio = try Studio(store: WorkspaceStore(path: ":memory:"))
    studio.setMode(.manual)
    let initialWorld = studio.worldID
    let command = try #require(
      CommandPalette.results(studio: studio, query: "Simulation", indexed: []).first {
        $0.title == "Simulation"
      })
    command.run()
    #expect(studio.destination == .simulation)
    #expect(studio.worldID == initialWorld && studio.mode == .manual && !studio.busy)
    #expect(try studio.store.simulationRuns(worldID: initialWorld).isEmpty)
  }

  @Test func authoredCalendarControlsProduceTheChosenInterval() throws {
    var form = SimulationRunForm()
    form.title = "Supply"
    form.unit = "crates"
    form.horizon = .hour
    #expect(try SimulationResourceSnapshot(scenario: form.scenario()).trace.map(\.hour) == [1])

    form.horizon = .year
    #expect(throws: SynthesisError.self) { try form.scenario() }
    form.hoursInYear = "8000"
    form.stepHours = "8000"
    #expect(try SimulationResourceSnapshot(scenario: form.scenario()).trace.map(\.hour) == [8000])

    form.horizon = .century
    let century = try SimulationResourceSnapshot(scenario: form.scenario())
    #expect(century.totalSteps == 100 && century.trace.last?.hour == 800_000)

    form.horizon = .custom
    form.hours = "125"
    form.stepHours = "25"
    #expect(
      try SimulationResourceSnapshot(scenario: form.scenario()).trace.map(\.hour)
        == [25, 50, 75, 100, 125])
  }
}
