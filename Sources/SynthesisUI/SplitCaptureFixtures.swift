import SynthesisCore

extension Studio {
  func configureSplitCapture(_ state: String, board: String, conversation: String) {
    closeSplitWorkspace()
    let base: String
    if state.contains("atlas") {
      base = "atlas-linked"
    } else if state.contains("timeline") {
      base = "timeline"
    } else if state.contains("graph") {
      base = "graph"
    } else if state.contains("canvas") {
      base = "canvas"
    } else {
      base = "editor"
    }
    configureConnectedCapture(base, board: board, conversation: conversation)
    dark = !state.hasPrefix("light-")
    if state.hasPrefix("manual-") { setMode(.manual) }
    inspector = false
    workspaceInspector = false
    setPanelWidth(.split, to: 460, persist: false)
    guard let character = records.first(where: { $0.title == "Mira Vale" }) else { return }
    if base == "editor", let sea = records.first(where: { $0.title == "The Glass Sea" }) {
      openRecord(sea)
    }
    openBeside(character)
    if state == "split-swapped" { swapSplitWorkspace() }
    if state == "split-closed" { closeSplitWorkspace() }
    if state == "split-picker" { sheet = .splitRecord }
    if state == "split-inspector" { splitInspector = true }
    if state == "split-long" {
      perform {
        let title = "The last cartographer of the western archipelago and its vanished shores"
        let record =
          try records.first(where: { $0.title == title })
          ?? store.createRecord(
            worldID: worldID, title: title,
            body: "Her records trace a coastline that changes with every winter.",
            kind: "entity", category: "Characters")
        try reload()
        openBeside(record)
      }
    }
    captureHint = state
  }
}
