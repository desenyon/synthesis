import Foundation
import Testing

@testable import SynthesisUI

struct GraphNeighborhoodTests {
  @Test func expansionFindsBothDirectionsWithoutCrossingMissingNodes() throws {
    let nodeIDs: Set<String> = ["mira", "order", "atlas", "city", "isolated", "outside"]
    let edges = [
      ("order", "mira"), ("order", "atlas"), ("atlas", "city"), ("city", "order"),
      ("mira", "missing"), ("missing", "outside"), ("city", "city"),
    ]

    let one = try #require(
      GraphNeighborhood(rootID: "mira", depth: 1).project(nodeIDs: nodeIDs, edges: edges))
    #expect(one.nodeIDs == ["mira", "order"])
    #expect(one.canExpand)

    let two = try #require(
      GraphNeighborhood(rootID: "mira", depth: 2).project(nodeIDs: nodeIDs, edges: edges))
    #expect(two.nodeIDs == ["mira", "order", "atlas", "city"])
    #expect(!two.canExpand)

    #expect(
      GraphNeighborhood(rootID: "missing", depth: 2).project(nodeIDs: nodeIDs, edges: edges) == nil)
  }

  @Test func arbitraryDepthIsBoundedByTheConnectedComponent() throws {
    let nodeIDs: Set<String> = ["a", "b", "c", "d", "e", "isolated"]
    let edges = [("a", "b"), ("c", "b"), ("c", "d"), ("d", "e")]
    let three = try #require(
      GraphNeighborhood(rootID: "a", depth: 3).project(nodeIDs: nodeIDs, edges: edges))
    #expect(three.nodeIDs == ["a", "b", "c", "d"])
    #expect(three.canExpand)

    let exhausted = try #require(
      GraphNeighborhood(rootID: "a", depth: Int.max).project(nodeIDs: nodeIDs, edges: edges))
    #expect(exhausted.nodeIDs == ["a", "b", "c", "d", "e"])
    #expect(!exhausted.canExpand)

    let isolated = try #require(
      GraphNeighborhood(rootID: "isolated", depth: 1).project(nodeIDs: nodeIDs, edges: edges))
    #expect(isolated.nodeIDs == ["isolated"])
    #expect(!isolated.canExpand)
  }

  @Test func graphSessionDecodesLegacyAndCurrentState() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let legacy = Data(
      #"{"positions":{},"signature":"","zoom":1,"pan":[0,0],"query":"","framed":false}"#.utf8)
    #expect(try decoder.decode(GraphViewState.self, from: legacy).neighborhood == nil)

    var state = GraphViewState()
    state.neighborhood = GraphNeighborhood(rootID: "mira", depth: 2)
    #expect(try decoder.decode(GraphViewState.self, from: encoder.encode(state)) == state)
    #expect(state.reconciled(records: []).neighborhood == nil)
  }
}
