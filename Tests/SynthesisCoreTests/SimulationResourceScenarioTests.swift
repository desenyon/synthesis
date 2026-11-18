import Foundation
import Testing

@testable import SynthesisCore

struct SimulationResourceScenarioTests {
  @Test func authoredPressureDepletesSupplyAndExplainsShortages() throws {
    let scenario = SimulationResourceScenario(
      horizonHours: 144, stepHours: 24, seed: 11, initialStock: 30, capacity: 50,
      parameters: .init(replenishment: 10, demand: 12, pressure: 5))
    let trace = try scenario.trace()

    #expect(trace.map(\.hour) == [24, 48, 72, 96, 120, 144])
    #expect(trace.map(\.closingStock) == [23, 16, 9, 2, 0, 0])
    #expect(trace.map(\.unmetDemand) == [0, 0, 0, 0, 5, 7])
    #expect(trace.allSatisfy { $0.replenishment == 5 && $0.parameters.pressure == 5 })
  }

  @Test func identicalSavedInputsReplayTheSameSeededTrace() throws {
    let scenario = SimulationResourceScenario(
      horizonHours: 4, seed: 0, initialStock: 5, capacity: 8,
      parameters: .init(replenishment: 3, demand: 4, supplyVariation: 2))
    let data = try JSONEncoder().encode(scenario)
    let restored = try JSONDecoder().decode(SimulationResourceScenario.self, from: data)

    #expect(try restored.trace() == scenario.trace())
    #expect(try restored.trace().map(\.supplyVariation) == [-2, -2, 2, 2])
    #expect(try restored.trace().map(\.closingStock) == [2, 0, 1, 2])
  }

  @Test func largeSeedIsPortableAsAnExactDecimalString() throws {
    let scenario = SimulationResourceScenario(
      horizonHours: 24, seed: UInt64.max, initialStock: 5, capacity: 8,
      parameters: .init(replenishment: 3, demand: 4, supplyVariation: 2))
    let data = try JSONEncoder().encode(scenario)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["seed"] as? String == "18446744073709551615")
    let restored = try JSONDecoder().decode(SimulationResourceScenario.self, from: data)
    #expect(try restored.trace() == scenario.trace())
  }

  @Test func interventionChangesFutureStepsAndCanBeReplayed() throws {
    let initial = SimulationResourceScenario(
      horizonHours: 4, seed: 1, initialStock: 5, capacity: 8,
      parameters: .init(replenishment: 0, demand: 2))
    let paused = try initial.trace(through: 2)
    let changed = try initial.adding(
      [.adjustStock(20), .setParameters(.init(replenishment: 4, demand: 2))],
      after: paused.count)
    let trace = try changed.trace()

    #expect(Array(trace.prefix(2)) == paused)
    #expect(trace.map(\.closingStock) == [3, 1, 8, 8])
    #expect(trace.map(\.discarded) == [0, 0, 15, 2])
    #expect(trace[2].stockAdjustment == 20)
    #expect(trace[2].actions == changed.interventions.map(\.action))
    #expect(try initial.trace().map(\.closingStock) == [3, 1, 0, 0])
  }

  @Test func invalidIntervalsAndBackdatedSchedulesDoNotRun() throws {
    let uneven = SimulationResourceScenario(
      horizonHours: 23, stepHours: 12, seed: 0, initialStock: 0, capacity: 1,
      parameters: .init(replenishment: 0, demand: 0))
    #expect(throws: SynthesisError.self) { try uneven.trace() }

    let scenario = SimulationResourceScenario(
      horizonHours: 4, seed: 1, initialStock: 0, capacity: 1,
      parameters: .init(replenishment: 0, demand: 0))
    let changed = try scenario.adding([.adjustStock(1)], after: 2)
    #expect(throws: SynthesisError.self) { try changed.adding([.adjustStock(1)], after: 1) }
    #expect(throws: SynthesisError.self) { try changed.adding([.adjustStock(1)], after: 4) }
    #expect(throws: SynthesisError.self) { try changed.trace(through: 5) }
  }

  @Test func stockReductionsCannotRemoveMoreThanTheAvailableStock() throws {
    let initial = SimulationResourceScenario(
      horizonHours: 1, seed: 1, initialStock: 2, capacity: 8,
      parameters: .init(replenishment: 0, demand: 1))
    let changed = try initial.adding([.adjustStock(-12)], after: 0)
    let step = try #require(try changed.trace().first)

    #expect(step.closingStock == 0)
    #expect(step.unmetDemand == 1)
    #expect(step.stockAdjustment == -2)
  }
}
