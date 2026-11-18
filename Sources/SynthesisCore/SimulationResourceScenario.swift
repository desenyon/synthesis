import Foundation

/// Authored quantities per step for a fictional reserve. Pressure deducts from replenishment
/// before any seeded supply variation. All amounts use one creator-selected unit.
public struct SimulationResourceParameters: Codable, Equatable, Sendable {
  public let replenishment: Int64
  public let demand: Int64
  public let pressure: Int64
  public let supplyVariation: Int64

  public init(
    replenishment: Int64, demand: Int64, pressure: Int64 = 0, supplyVariation: Int64 = 0
  ) {
    self.replenishment = replenishment
    self.demand = demand
    self.pressure = pressure
    self.supplyVariation = supplyVariation
  }
}

public enum SimulationResourceAction: Codable, Equatable, Sendable {
  case adjustStock(Int64)
  case setParameters(SimulationResourceParameters)
}

/// An authored change at the start of a one-based simulation step.
public struct SimulationResourceIntervention: Codable, Equatable, Sendable {
  public let step: Int
  public let action: SimulationResourceAction
}

/// A calculation trace row. Each field is an actual quantity applied by the engine.
public struct SimulationResourceStep: Codable, Equatable, Sendable {
  public let hour: Int64
  public let openingStock: Int64
  public let stockAdjustment: Int64
  public let actions: [SimulationResourceAction]
  public let parameters: SimulationResourceParameters
  public let supplyVariation: Int64
  public let replenishment: Int64
  public let consumed: Int64
  public let unmetDemand: Int64
  public let discarded: Int64
  public let closingStock: Int64
}

/// A standalone, hypothetical input snapshot. It carries no authority to edit the workspace.
public struct SimulationResourceScenario: Codable, Equatable, Sendable {
  private static let currentEngineVersion = 1
  private static let quantityLimit: Int64 = 1_000_000_000

  public let engineVersion: Int
  public let horizonHours: Int64
  public let stepHours: Int64
  public let seed: String
  public let initialStock: Int64
  public let capacity: Int64
  public let parameters: SimulationResourceParameters
  public private(set) var interventions: [SimulationResourceIntervention] = []

  public init(
    horizonHours: Int64, stepHours: Int64 = 1, seed: UInt64, initialStock: Int64, capacity: Int64,
    parameters: SimulationResourceParameters
  ) {
    engineVersion = Self.currentEngineVersion
    self.horizonHours = horizonHours
    self.stepHours = stepHours
    self.seed = String(seed)
    self.initialStock = initialStock
    self.capacity = capacity
    self.parameters = parameters
  }

  /// Schedules changes at the next step. Earlier calculated rows can be reproduced unchanged.
  public func adding(_ actions: [SimulationResourceAction], after completedSteps: Int) throws
    -> Self
  {
    let (stepCount, _) = try validatedInput()
    guard completedSteps >= 0, completedSteps < stepCount,
      completedSteps + 1 >= (interventions.last?.step ?? 1),
      actions.count <= 256 - interventions.count
    else {
      throw SynthesisError.invalid("Add interventions at the current or a later pause.")
    }
    var result = self
    result.interventions.append(
      contentsOf: actions.map {
        SimulationResourceIntervention(step: completedSteps + 1, action: $0)
      })
    _ = try result.validatedInput()
    return result
  }

  public func trace(through completedSteps: Int? = nil) throws -> [SimulationResourceStep] {
    let (stepCount, seed) = try validatedInput()
    let count = completedSteps ?? stepCount
    guard (0...stepCount).contains(count) else {
      throw SynthesisError.invalid("The requested step is outside the scenario.")
    }

    var result: [SimulationResourceStep] = []
    result.reserveCapacity(count)
    var stock = initialStock
    var terms = parameters
    var schedule = interventions[...]
    for index in 0..<count {
      let step = index + 1
      let opening = stock
      var actions: [SimulationResourceAction] = []
      while let intervention = schedule.first, intervention.step == step {
        switch intervention.action {
        case .adjustStock(let amount): stock = max(0, stock + amount)
        case .setParameters(let parameters): terms = parameters
        }
        actions.append(intervention.action)
        schedule.removeFirst()
      }
      let adjustment = stock - opening
      let variance = Self.supplyVariation(seed: seed, at: step, amplitude: terms.supplyVariation)
      let replenishment = max(0, terms.replenishment - terms.pressure + variance)
      let available = stock + replenishment
      let consumed = min(available, terms.demand)
      let remaining = available - consumed
      stock = min(capacity, remaining)
      result.append(
        SimulationResourceStep(
          hour: Int64(step) * stepHours, openingStock: opening, stockAdjustment: adjustment,
          actions: actions, parameters: terms, supplyVariation: variance,
          replenishment: replenishment,
          consumed: consumed, unmetDemand: terms.demand - consumed, discarded: remaining - stock,
          closingStock: stock))
    }
    return result
  }

  private func validatedInput() throws -> (steps: Int, seed: UInt64) {
    guard engineVersion == Self.currentEngineVersion else {
      throw SynthesisError.invalid("This simulation engine version is unavailable.")
    }
    guard horizonHours > 0, stepHours > 0, horizonHours % stepHours == 0,
      horizonHours / stepHours <= 10_000
    else {
      throw SynthesisError.invalid("Choose a positive horizon with 1–10,000 equal steps.")
    }
    guard let seed = UInt64(self.seed), String(seed) == self.seed else {
      throw SynthesisError.invalid("The simulation seed must be a 64-bit unsigned integer.")
    }
    let stepCount = Int(horizonHours / stepHours)
    let limit = Self.quantityLimit
    guard (1...limit).contains(capacity), (0...capacity).contains(initialStock),
      Self.valid(parameters), interventions.count <= 256
    else {
      throw SynthesisError.invalid("The starting amounts or scenario limits are invalid.")
    }

    var previousStep = 1
    for intervention in interventions {
      guard (previousStep...stepCount).contains(intervention.step) else {
        throw SynthesisError.invalid("Simulation interventions are out of order or out of range.")
      }
      switch intervention.action {
      case .adjustStock(let amount):
        guard (-limit...limit).contains(amount) else {
          throw SynthesisError.invalid("The stock adjustment is outside the supported range.")
        }
      case .setParameters(let parameters):
        guard Self.valid(parameters) else {
          throw SynthesisError.invalid("The intervention amounts are outside the supported range.")
        }
      }
      previousStep = intervention.step
    }
    return (stepCount, seed)
  }

  private static func valid(_ parameters: SimulationResourceParameters) -> Bool {
    let range = 0...quantityLimit
    return range.contains(parameters.replenishment) && range.contains(parameters.demand)
      && range.contains(parameters.pressure) && range.contains(parameters.supplyVariation)
  }

  /// SplitMix64's integer mixer at a fixed step offset. Seed 0 works, and replay does not
  /// depend on the platform RNG, dictionary order, or how many earlier steps were inspected.
  private static func supplyVariation(seed: UInt64, at step: Int, amplitude: Int64) -> Int64 {
    guard amplitude > 0 else { return 0 }
    var value = seed &+ (UInt64(step) &* 0x9e37_79b9_7f4a_7c15)
    value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
    value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
    value ^= value >> 31
    return Int64(value % UInt64(2 * amplitude + 1)) - amplitude
  }
}
