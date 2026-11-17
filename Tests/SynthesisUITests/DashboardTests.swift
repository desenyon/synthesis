import SynthesisCore
import Testing

@testable import SynthesisUI

@MainActor struct DashboardTests {
  @Test func sectionsUseLiveDataAndActionsPreserveManualAndCanon() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    studio.setMode(.manual)
    studio.navigate(.dashboard)
    let person = try store.createRecord(worldID: studio.worldID, title: "Mira", kind: "entity")
    _ = try store.createRecord(worldID: studio.worldID, title: "Scene", body: "Work in progress")
    let accepted = try store.createRecord(worldID: studio.worldID, title: "Established history")
    _ = try store.promote(
      worldID: studio.worldID, id: accepted.id, version: accepted.version, confirmation: accepted.id
    )
    _ = try store.createRecordSection(
      worldID: studio.worldID, parentID: person.id, title: "Not a standalone draft")
    studio.createProject("A campaign")
    let project = try #require(studio.selectedRecord)
    #expect(project.isProject && project.canonical == nil)
    #expect(studio.dashboardProjects.map(\.id) == [project.id])
    #expect(studio.dashboardEntities.map(\.id) == [person.id])
    #expect(studio.dashboardWriting.map(\.title) == ["Scene"])
    studio.navigate(.dashboard)
    let item = try #require(
      store.recentWorldActivity(worldID: studio.worldID).first { $0.objectID == person.id })
    studio.openActivity(item)
    #expect(studio.selectedRecord?.id == person.id && studio.mode == .manual && !studio.busy)
    studio.goBack()
    #expect(studio.destination == .dashboard && studio.selectedRecord == nil)
    let before = studio.navigationLocation
    studio.editorSave = { false }
    studio.openActivity(item)
    studio.createProject("Must not be created")
    #expect(studio.navigationLocation == before)
    #expect(
      try !store.records(worldID: studio.worldID).contains { $0.title == "Must not be created" })
  }

  @Test func reviewMapLinksStartupAndForeignActivityAreGuarded() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let studio = try Studio(store: store)
    let proposal = try #require(
      try store.stageProposal(
        worldID: studio.worldID, conversationID: nil, messageID: nil,
        payload: ["changes": [["action": "create_record", "title": "Possibility"]]]))
    try studio.reload()
    studio.navigate(.dashboard)
    studio.openProposalReview(proposal.id)
    #expect(studio.destination == .review && studio.reviewFocusID == proposal.id)
    #expect(try store.proposal(worldID: studio.worldID, id: proposal.id).pending == 1)
    let map = try store.createAtlasMap(worldID: studio.worldID, name: "Coast")
    let activity = try #require(
      store.recentWorldActivity(worldID: studio.worldID).first { $0.objectID == map.id })
    studio.openActivity(activity)
    #expect(studio.destination == .atlas && studio.mapBoardID == map.id)
    let other = try store.createWorld(name: "Other")
    studio.switchWorld(other.id)
    studio.navigate(.dashboard)
    studio.openActivity(activity)
    #expect(studio.destination == .dashboard && studio.selectedRecord == nil)
    #expect(studio.dashboardEntities.isEmpty && studio.dashboardProjects.isEmpty)
    studio.updatePreferences { $0.launchWorkspace = "Dashboard" }
    #expect(try Studio(store: store).destination == .dashboard)
    let command = CommandPalette.results(studio: studio, query: "Dashboard", indexed: []).first
    #expect(command?.title == "Dashboard" && command?.detail == "")
  }
}
