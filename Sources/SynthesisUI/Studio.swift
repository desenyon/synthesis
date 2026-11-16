import AppKit
import SwiftUI
import SynthesisCore

public enum Destination: String, CaseIterable, Identifiable {
  case chat = "Conversation"
  case canvas = "Canvas"
  case library = "Library"
  case knowledge = "Graph"
  case timeline = "Timeline"
  case atlas = "Atlas"
  case review = "Review"
  case worlds = "Worlds"
  case settings = "Settings"
  public var id: String { rawValue }
  var icon: String {
    switch self {
    case .chat: return "bubble.left"
    case .canvas: return "rectangle.on.rectangle"
    case .library: return "books.vertical"
    case .knowledge: return "point.3.connected.trianglepath.dotted"
    case .timeline: return "calendar.day.timeline.left"
    case .atlas: return "map"
    case .review: return "checkmark.seal"
    case .worlds: return "globe"
    case .settings: return "gearshape"
    }
  }
  var summary: String {
    switch self {
    case .chat: return "Think with your world"
    case .canvas: return "Arrange ideas by hand"
    case .library: return "Every document, entity and idea"
    case .knowledge: return "Relationships between entities"
    case .timeline: return "Events in order"
    case .atlas: return "Places on your map"
    case .review: return "Proposals, canon and checks"
    case .worlds: return "Open, save and organize your universes"
    case .settings: return "Application and world preferences"
    }
  }
}

/// A short, auto-dismissing confirmation with an optional reversal.
public struct Toast: Identifiable {
  public let id = UUID()
  var message: String
  var icon = "checkmark.circle"
  var actionTitle: String?
  var action: (() -> Void)?
}

@MainActor public final class Studio: ObservableObject {
  public let store: WorkspaceStore
  public let engine: AgentEngine
  @Published public var worlds: [World] = []
  @Published public var worldID = ""
  @Published public var worldRevision = 0
  @Published public var reviewingProposal = false
  @Published public var records: [LoreRecord] = []
  @Published public var recordSectionTabs: [String: Bool] = [:]
  @Published public var sectionParents: [String: String] = [:]
  public var topLevelRecords: [LoreRecord] { records.filter { sectionParents[$0.id] == nil } }

  @Published public var conversations: [Conversation] = []
  @Published public var messages: [ChatMessage] = []
  /// Staged AI change sets for the open conversation, keyed by the message that proposed them.
  @Published public var proposals: [String: Proposal] = [:]
  /// Every staged change set in this world that still has something to decide.
  @Published public var pendingProposals: [Proposal] = []
  /// The canvas engine and its web view, created the first time Canvas is shown and kept for
  /// the rest of the run.
  var canvasSession: CanvasSession?
  func canvas() -> CanvasSession {
    if let canvasSession { return canvasSession }
    let session = CanvasSession(studio: self)
    canvasSession = session
    return session
  }
  /// Gives the canvas a moment to hand over unsaved edits; used before the app quits.
  public func flushCanvas() async -> Bool {
    guard let canvasSession else { return true }
    await canvasSession.flush()
    return canvasSession.failure == nil
  }
  public var canvasWebView: NSView? { canvasSession?.webView }
  public var canvasLoaded: Bool { canvasSession?.loaded ?? false }
  /// Opens Canvas with this record's card selected, adding the card if the board lacks it.
  public func showOnCanvas(_ record: LoreRecord) {
    guard flushEditor() else { return }
    navigate(.canvas)
    canvas().reveal(record)
  }
  /// Puts references to the selected canvas cards into the message being written.
  public func referenceCanvasSelection() {
    let chosen = (canvasSession?.selection ?? []).compactMap { id in records.first { $0.id == id } }
    guard !chosen.isEmpty else { return }
    for record in chosen { reference(record) }
    if mode == .assisted { companionExpanded = true }
  }
  public func canvasCommand(_ name: String) { canvasSession?.command(name) }
  /// Record whose canon review should open as soon as its editor appears.
  public var reviewCanon: String?
  /// Records shared with the model for each answer, keyed by assistant message.
  @Published public var contexts: [String: [ContextSource]] = [:]
  @Published public var conversationID: String?
  @Published public var selectedRecord: LoreRecord?
  @Published public var destination: Destination = .chat
  @Published public var mode: WorkspaceMode = .assisted
  @Published public var dark = false
  @Published public var worldCover: NSImage?
  @Published public var collapsed = false
  @Published public var mobileNavigation = false
  @Published public var draft = ""
  @Published public var preset = "Create"
  @Published public var busy = false
  @Published public var streamed = ""
  @Published public var error: String?
  @Published public var toast: Toast?
  @Published public var sheet: Sheet?
  @Published public var palette = false
  @Published public var providerConfigured = false
  @Published public var provider = ProviderKind.claudeCode
  @Published public var providerStatus: ProviderStatus?
  @Published public var checkingProvider = false
  @Published public var harnessModels: [ProviderKind: String] = [:]
  @Published public var editorSave: (() -> Bool)?
  @Published public var canvasBoardID: String?
  @Published public var mapBoardID: String?
  @Published public var companionExpanded = false
  @Published public var companionWidth = 400.0
  @Published public var libraryCategory: String?
  @Published public var newRecordKind = "lore"
  @Published public var inspector = true
  /// Set only by the isolated capture runner so a screenshot can show a selected state.
  @Published public var captureHint = ""
  /// Bumped by the capture runner to rebuild the workspace for each screenshot.
  @Published public var captureNonce = 0
  /// Conversation the rename sheet edits; defaults to the open conversation.
  public var renameTarget: String?
  var pendingComposer: (world: String, text: String)?
  public var canvasUndo: ((Bool) -> Void)?
  public var canvasFit: (() -> Void)?
  private var running: Task<Void, Never>?
  private var requestID = UUID()
  private var toastTask: Task<Void, Never>?
  public enum Sheet: String, Identifiable {
    case settings, world, document, rename, onboarding
    public var id: String { rawValue }
  }
  public var world: World? { worlds.first { $0.id == worldID } }
  public var t: Theme { Theme(dark: dark) }
  public var conversationTitle: String {
    conversations.first { $0.id == conversationID }?.title ?? "New conversation"
  }
  public init(store: WorkspaceStore, transport: (any ModelTransport)? = nil) throws {
    self.store = store
    // Requests go to whichever provider is selected when they are sent. The transports read
    // the choice from defaults so they stay independent of this observable object.
    let setting: @Sendable (String) -> String = {
      UserDefaults.standard.string(forKey: $0) ?? ""
    }
    self.engine = AgentEngine(
      store: store,
      transport: transport
        ?? ProviderRouter(
          kind: { ProviderKind(rawValue: setting("Synthesis.provider")) ?? .claudeCode },
          claude: ClaudeCodeTransport(model: { setting("Synthesis.model.claude-code") }),
          codex: CodexTransport(model: { setting("Synthesis.model.codex") })))
    // Migrate obsolete API selection to an installed subscription harness.
    provider =
      try store.preference("provider").flatMap(ProviderKind.init(rawValue:))
      ?? .codex
    try store.setPreference("provider", value: provider.rawValue)
    UserDefaults.standard.set(provider.rawValue, forKey: "Synthesis.provider")
    for kind in [ProviderKind.claudeCode, .codex] {
      let value = try store.preference("model:\(kind.rawValue)") ?? ""
      harnessModels[kind] = value
      UserDefaults.standard.set(value, forKey: "Synthesis.model.\(kind.rawValue)")
    }
    worlds = try store.worlds()
    let firstLaunch = worlds.isEmpty
    if worlds.isEmpty { worlds = [try store.createWorld(name: "My world")] }
    let last = try store.preference("world")
    worldID = worlds.first { $0.id == last }?.id ?? worlds[0].id
    worldCover = Self.cover(store: store, worldID: worldID)
    mode = WorkspaceMode(rawValue: try store.preference("mode") ?? "assisted") ?? .assisted
    dark = try store.preference("theme") != "light"
    collapsed = try store.preference("sidebar") == "collapsed"
    inspector = try store.preference("inspector") != "hidden"
    destination =
      try store.preference("destination").flatMap(Destination.init(rawValue:))
      ?? (mode == .manual ? .canvas : .chat)
    draft = try store.preference("composer:\(worldID)") ?? ""
    refreshProviderAvailability()
    try reload()
    if try store.preference("onboarding-completed") == nil {
      if firstLaunch && ProcessInfo.processInfo.environment["SYNTHESIS_CAPTURE_DIR"] == nil {
        sheet = .onboarding
      } else {
        try store.setPreference("onboarding-completed", value: "1")
      }
    }
  }
  public func completeOnboarding() {
    perform {
      try store.setPreference("onboarding-completed", value: "1")
      sheet = nil
    }
  }

  // MARK: Provider

  /// Installation enables setup; every generation rechecks subscription authentication.
  public func refreshProviderAvailability() {
    providerConfigured = HarnessLocator.find(provider) != nil && providerStatus?.signedIn != false
  }
  public func setProvider(_ kind: ProviderKind) {
    guard kind != provider else { return }
    stop()
    perform {
      try store.setPreference("provider", value: kind.rawValue)
      provider = kind
      UserDefaults.standard.set(kind.rawValue, forKey: "Synthesis.provider")
      providerStatus = nil
      checkingProvider = false
      refreshProviderAvailability()
    }
  }
  public func setHarnessModel(_ value: String, for kind: ProviderKind) {
    let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
    perform {
      try store.setPreference("model:\(kind.rawValue)", value: model)
      harnessModels[kind] = model
      UserDefaults.standard.set(model, forKey: "Synthesis.model.\(kind.rawValue)")
    }
  }
  /// Asks the harness for its own sign-in status. No model request is made.
  public func checkProvider() {
    let kind = provider
    checkingProvider = true
    Task { @MainActor [weak self] in
      let status = await ProviderStatus.check(kind)
      guard let self, self.provider == kind else { return }
      self.providerStatus = status
      self.checkingProvider = false
      self.refreshProviderAvailability()
    }
  }
  /// One line for the composer: who receives a message if it is sent now.
  public var providerDisclosure: String {
    "Sending shares this message and world context with \(provider.recipient)."
  }
  public func reload() throws {
    defer { worldRevision += 1 }
    worlds = try store.worlds()
    sectionParents = try store.sectionMemberships(worldID: worldID)
    records = try store.records(worldID: worldID)
    conversations = try store.conversations(worldID: worldID)
    pendingProposals = try store.proposals(worldID: worldID).filter { $0.pending > 0 }
    if let conversationID {
      messages = try store.messages(worldID: worldID, conversationID: conversationID)
      proposals = Dictionary(
        try store.proposals(worldID: worldID, conversationID: conversationID).compactMap {
          proposal in proposal.messageID.map { ($0, proposal) }
        }, uniquingKeysWith: { _, latest in latest })
      contexts = try store.messageContext(worldID: worldID, conversationID: conversationID)
    } else {
      messages = []
      proposals = [:]
      contexts = [:]
    }
  }

  // MARK: Proposals

  /// The creator's explicit decision on one staged change. Accepted changes become drafts.
  public func resolve(_ proposal: Proposal, change: ProposedChange, accept: Bool) {
    resolve(proposal, changes: [change], accept: accept)
  }
  public func resolveAll(_ proposal: Proposal, accept: Bool) {
    resolve(proposal, changes: proposal.changes.filter { $0.status == "pending" }, accept: accept)
  }
  private func resolve(_ proposal: Proposal, changes: [ProposedChange], accept: Bool) {
    guard !reviewingProposal, flushEditor() else { return }
    let world = worldID
    reviewingProposal = true
    Task {
      defer { reviewingProposal = false }
      guard await flushCanvas(), world == worldID else { return }
      perform {
        defer {
          try? reload()
          if accept && changes.contains(where: { $0.action == "place_record" }) {
            canvasSession?.reloadStoredBoard()
          }
        }
        for change in changes {
          _ = try store.resolveChange(
            worldID: world, proposalID: proposal.id, changeID: change.id,
            accept: accept, confirmation: proposal.id)
        }
        show(accept ? "Saved reviewed changes. Canon is unchanged." : "Changes dismissed.")
      }
    }
  }
  /// Drafts whose accepted canon is older than their current text.
  public var canonQueue: [LoreRecord] {
    records.filter { $0.canonical != nil && $0.state != "canon" }
  }
  /// Things waiting on the creator: staged proposals plus drafts that moved past canon.
  public var reviewCount: Int { pendingProposals.count + canonQueue.count }
  /// Display name for a proposal endpoint: a record, or something the same proposal creates.
  public func name(for reference: String?, in proposal: Proposal) -> String {
    guard let reference else { return "Unknown" }
    if reference.hasPrefix("change:") {
      return proposal.changes.first { "change:\($0.id)" == reference }?.title ?? "New record"
    }
    return records.first { $0.id == reference }?.title ?? "Archived record"
  }
  public func perform(_ body: () throws -> Void) {
    do { try body() } catch {
      self.error = error.localizedDescription
    }
  }
  public func show(
    _ message: String, icon: String = "checkmark.circle", actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    let value = Toast(message: message, icon: icon, actionTitle: actionTitle, action: action)
    toast = value
    toastTask?.cancel()
    toastTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(action == nil ? 3.5 : 7))
      guard !Task.isCancelled, self?.toast?.id == value.id else { return }
      withAnimation(.easeOut(duration: 0.18)) { self?.toast = nil }
    }
  }
  public func persistPendingComposer() {
    if let pendingComposer, pendingComposer.world == worldID {
      draft = pendingComposer.text
      self.pendingComposer = nil
    }
    persistComposer()
  }
  public func persistComposer() {
    perform { try store.setPreference("composer:\(worldID)", value: draft) }
  }
  public func setMode(_ value: WorkspaceMode) {
    guard value != mode else { return }
    perform {
      try engine.setMode(value)
      mode = value
      stop()
      // Assistance is independent of navigation. Keep editors and boards intact.
      if value == .manual {
        companionExpanded = false
      }
      try reload()
    }
  }
  public func toggleTheme() {
    dark.toggle()
    perform { try store.setPreference("theme", value: dark ? "dark" : "light") }
  }
  public func toggleSidebar() {
    collapsed.toggle()
    perform { try store.setPreference("sidebar", value: collapsed ? "collapsed" : "expanded") }
  }
  public func toggleInspector() {
    inspector.toggle()
    perform { try store.setPreference("inspector", value: inspector ? "shown" : "hidden") }
  }
  public func flushEditor() -> Bool { editorSave?() ?? true }
  public func navigate(_ value: Destination) {
    guard flushEditor() else { return }
    selectedRecord = nil
    editorSave = nil
    destination = value
    if value != .canvas {
      canvasUndo = nil
      canvasFit = nil
    }
    if value != .library { libraryCategory = nil }
    mobileNavigation = false
    try? store.setPreference("destination", value: value.rawValue)
  }
  public func openLens(_ category: String?) {
    guard flushEditor() else { return }
    selectedRecord = nil
    editorSave = nil
    libraryCategory = category
    destination = .library
    canvasUndo = nil
    canvasFit = nil
    mobileNavigation = false
    try? store.setPreference("destination", value: Destination.library.rawValue)
  }
  public func switchWorld(_ id: String) {
    guard id != worldID else { return }
    guard flushEditor() else { return }
    stop()
    perform {
      persistPendingComposer()
      canvasBoardID = nil
      mapBoardID = nil
      companionExpanded = false
      libraryCategory = nil
      worldID = id
      worldCover = Self.cover(store: store, worldID: id)
      conversationID = nil
      selectedRecord = nil
      editorSave = nil
      try store.setPreference("world", value: id)
      draft = try store.preference("composer:\(id)") ?? ""
      try reload()
    }
  }
  public func newChat(keepWorkspace: Bool = false) {
    guard flushEditor() else { return }
    stop()
    if !keepWorkspace {
      selectedRecord = nil
      editorSave = nil
      destination = .chat
    }
    conversationID = nil
    messages = []
    mobileNavigation = false
  }
  public func openChat(_ chat: Conversation, keepWorkspace: Bool = false) {
    guard flushEditor() else { return }
    stop()
    perform {
      conversationID = chat.id
      if !keepWorkspace {
        selectedRecord = nil
        editorSave = nil
        destination = .chat
      }
      try reload()
      mobileNavigation = false
    }
  }
  /// Opens a record over the current workspace; closing returns to where the creator was.
  public func openRecord(_ record: LoreRecord) {
    guard flushEditor() else { return }
    selectedRecord = record
    editorSave = nil
    mobileNavigation = false
  }
  public func closeRecord() {
    guard flushEditor() else { return }
    selectedRecord = nil
    editorSave = nil
  }
  public func createRecord(
    title: String, kind: String = "lore", body: String = "", category: String = ""
  ) {
    perform {
      let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
      let record = try store.createRecord(
        worldID: worldID,
        title: name.isEmpty ? "Untitled \(Vocabulary.kindLabel(kind).lowercased())" : name,
        body: body, kind: kind, category: category)
      try reload()
      openRecord(record)
      sheet = nil
    }
  }
  public func createWorld(_ name: String) {
    perform {
      let world = try store.createWorld(name: name)
      try reload()
      switchWorld(world.id)
      sheet = nil
    }
  }
  public func renameWorld(_ name: String) {
    perform {
      _ = try store.renameWorld(worldID, name: name)
      try reload()
    }
  }

  // MARK: Reversible removal

  public func archive(_ record: LoreRecord) {
    if selectedRecord?.id == record.id {
      guard flushEditor() else { return }
      selectedRecord = nil
      editorSave = nil
    }
    perform {
      try store.archiveRecord(worldID: worldID, id: record.id)
      try reload()
      show("Archived “\(record.title)”", icon: "archivebox", actionTitle: "Undo") { [weak self] in
        self?.restore(recordID: record.id)
      }
    }
  }
  public func restore(recordID: String) {
    perform {
      try store.restoreRecord(worldID: worldID, id: recordID)
      try reload()
    }
  }
  public func archive(_ chat: Conversation) {
    if conversationID == chat.id { stop() }
    perform {
      try store.setConversationArchived(worldID: worldID, id: chat.id, archived: true)
      if conversationID == chat.id {
        conversationID = nil
        messages = []
      }
      try reload()
      show("Archived “\(chat.title)”", icon: "archivebox", actionTitle: "Undo") { [weak self] in
        self?.restore(conversationID: chat.id)
      }
    }
  }
  public func restore(conversationID id: String) {
    perform {
      try store.setConversationArchived(worldID: worldID, id: id, archived: false)
      try reload()
    }
  }

  // MARK: Conversation

  public func stop() {
    requestID = UUID()
    engine.cancel()
    running?.cancel()
    running = nil
    busy = false
    streamed = ""
  }
  public func send(keepWorkspace: Bool = false) {
    guard mode == .assisted, !busy, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }
    guard draft.count <= 30000 else {
      error = "Keep a message under 30,000 characters. Your text is still here."
      return
    }
    guard flushEditor() else { return }
    let activeBoard = destination == .canvas ? canvasSession?.boardID : nil
    let selectedIDs =
      selectedRecord.map { [$0.id] }
      ?? (destination == .canvas ? (canvasSession?.selection ?? []) : [])
    let prompt = draft
    let wid = worldID
    perform {
      if conversationID == nil {
        conversationID = try store.createConversation(worldID: worldID).id
      }
      let cid = conversationID!
      let chosenPreset = preset
      let request = UUID()
      requestID = request
      busy = true
      streamed = ""
      draft = ""
      persistComposer()
      if !keepWorkspace {
        selectedRecord = nil
        destination = .chat
      }
      running = Task { [weak self] in
        guard let self, !Task.isCancelled, self.requestID == request else { return }
        do {
          guard await self.flushCanvas(), self.worldID == wid, self.requestID == request else {
            throw SynthesisError.invalid("Canvas is not saved yet. Retry after the save completes.")
          }
          try await self.engine.submit(
            worldID: wid, conversationID: cid, prompt: prompt, preset: chosenPreset,
            boardID: activeBoard, selectedRecordIDs: selectedIDs
          ) { [weak self] output in
            await self?.receive(output, worldID: wid, conversationID: cid, request: request)
          }
        } catch {
          if !(error is CancellationError), self.requestID == request, self.worldID == wid,
            self.mode == .assisted
          {
            if case SynthesisError.unavailable = error {
            } else {
              if (try? self.store.messages(worldID: wid, conversationID: cid).last(where: {
                $0.role == "user"
              })?.body) != prompt {
                self.draft = prompt
                self.persistComposer()
              }
              self.error = error.localizedDescription
            }
          }
        }
        if self.requestID == request, self.worldID == wid, self.conversationID == cid {
          self.busy = false
          self.streamed = ""
          self.perform { try self.reload() }
        }
      }
      // The user message is committed by the core before the transport awaits.
      Task {
        await Task.yield()
        self.perform { try self.reload() }
      }
    }
  }
  private func receive(_ output: String, worldID: String, conversationID: String, request: UUID) {
    guard requestID == request, busy, self.worldID == worldID,
      self.conversationID == conversationID, mode == .assisted
    else { return }
    streamed = output
  }
  /// Saves a model answer as an AI-origin draft. It never becomes canon without separate review.
  public func saveResponse(_ message: ChatMessage, entity: Bool = false) {
    perform {
      let heading = message.body.split(separator: "\n").first.map(String.init) ?? ""
      let title = heading.trimmingCharacters(in: CharacterSet(charactersIn: "# *_")).prefix(80)
      let record = try store.createRecord(
        worldID: worldID,
        title: title.isEmpty ? (entity ? "New entity" : "Conversation draft") : String(title),
        body: message.body, kind: entity ? "entity" : "lore", origin: "ai-proposed")
      try reload()
      openRecord(record)
    }
  }
  /// Appends a lore reference to the composer draft.
  public func reference(_ record: LoreRecord) {
    let link = "[\(record.title)](synthesis://record/\(record.id))"
    let base = pendingComposer?.world == worldID ? pendingComposer!.text : draft
    pendingComposer = nil
    draft =
      base.isEmpty || base.hasSuffix(" ") || base.hasSuffix("\n")
      ? base + link + " "
      : base
        + " " + link + " "
    persistComposer()
  }
  public func attachText() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText, .text]
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
      perform {
        let data = try Data(contentsOf: url)
        guard data.count <= 50000, let text = String(data: data, encoding: .utf8) else {
          throw SynthesisError.invalid("Attach a UTF-8 text or Markdown file under 50 KB.")
        }
        draft += "\n\nAttached reference: \(url.lastPathComponent)\n\(text)"
        persistComposer()
      }
    }
  }

  // MARK: World

  private static func cover(store: WorkspaceStore, worldID: String) -> NSImage? {
    guard let value = try? store.preference("world-cover:\(worldID)"),
      let data = Data(base64Encoded: value)
    else { return nil }
    return NSImage(data: data)
  }
  public func chooseWorldCover() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    perform {
      let data = try Data(contentsOf: url)
      guard data.count <= 4_000_000, let image = NSImage(data: data) else {
        throw SynthesisError.invalid("Choose a world cover smaller than 4 MB.")
      }
      try store.setPreference("world-cover:\(worldID)", value: data.base64EncodedString())
      worldCover = image
    }
  }
  public func removeWorldCover() {
    perform {
      try store.setPreference("world-cover:\(worldID)", value: "")
      worldCover = nil
    }
  }
  /// Imports Markdown or text files as draft documents marked `imported`.
  public func importDocuments(_ urls: [URL]? = nil) {
    var files = urls ?? []
    if urls == nil {
      let panel = NSOpenPanel()
      panel.allowedContentTypes = [.plainText, .text]
      panel.allowsMultipleSelection = true
      panel.canChooseDirectories = false
      panel.message = "Choose Markdown or text files to add to \(world?.name ?? "this world")."
      guard panel.runModal() == .OK else { return }
      files = panel.urls
    }
    var imported: [LoreRecord] = []
    var skipped: [String] = []
    for url in files.prefix(200) {
      guard let data = try? Data(contentsOf: url), data.count <= 2_000_000,
        let text = String(data: data, encoding: .utf8),
        let record = try? store.importDocument(
          worldID: worldID, filename: url.lastPathComponent, text: text)
      else {
        skipped.append(url.lastPathComponent)
        continue
      }
      imported.append(record)
    }
    perform { try reload() }
    if imported.isEmpty {
      error =
        skipped.isEmpty
        ? nil : "Nothing was imported. Files must be UTF-8 text or Markdown under 2 MB."
      return
    }
    let ids = imported.map(\.id)
    show(
      "Imported \(imported.count) \(imported.count == 1 ? "document" : "documents") as drafts"
        + (skipped.isEmpty ? "" : " · \(skipped.count) skipped"),
      icon: "square.and.arrow.down", actionTitle: "Undo"
    ) { [weak self] in
      guard let self else { return }
      self.perform {
        for id in ids { try self.store.archiveRecord(worldID: self.worldID, id: id) }
        try self.reload()
      }
    }
    if imported.count == 1 { openRecord(imported[0]) } else { navigate(.library) }
  }
  /// Writes one Markdown file per record into a folder the creator chooses.
  public func exportMarkdown() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.prompt = "Export Here"
    panel.message = "A folder named after this world will be created inside the one you choose."
    guard panel.runModal() == .OK, let parent = panel.url else { return }
    perform {
      let files = try store.exportMarkdown(worldID: worldID)
      var root = parent.appendingPathComponent("\(world?.name ?? "World") — Synthesis export")
      var suffix = 2
      while FileManager.default.fileExists(atPath: root.path) {
        root = parent.appendingPathComponent(
          "\(world?.name ?? "World") — Synthesis export \(suffix)")
        suffix += 1
      }
      for file in files {
        let url = root.appendingPathComponent(file.path)
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try file.content.write(to: url, atomically: true, encoding: .utf8)
      }
      show(
        "Exported \(files.count) Markdown files", icon: "square.and.arrow.up", actionTitle: "Show"
      ) { NSWorkspace.shared.activateFileViewerSelecting([root]) }
    }
  }
  /// Saves a loose thought straight to the library without opening a form.
  public func capture(_ text: String) {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return }
    perform {
      let first = value.split(separator: "\n").first.map(String.init) ?? value
      let record = try store.createRecord(
        worldID: worldID, title: String(first.prefix(70)), body: value, kind: "capture",
        category: "Ideas")
      try reload()
      show("Captured as an idea", icon: "lightbulb", actionTitle: "Open") { [weak self] in
        self?.openRecord(record)
      }
    }
  }
  public func exportWorld() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(world?.name ?? "world").json"
    if panel.runModal() == .OK, let url = panel.url {
      perform {
        try store.exportWorld(worldID).write(to: url, options: .atomic)
        show("World exported to \(url.lastPathComponent)", icon: "square.and.arrow.up")
      }
    }
  }
  public func auditCanvas() async throws -> [String] { try await canvas().audit() }

  static func sampleArtwork() -> Data? {
    if let generated = StudioArtwork.atlas.data { return generated }
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("Assets/aster-coast.png")
    let url =
      bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
      ?? Bundle.module.url(forResource: "Assets", withExtension: nil)?.appendingPathComponent(
        "aster-coast.png")
    return url.flatMap { try? Data(contentsOf: $0) }
  }
  /// Opens the clearly labelled sample universe, creating it once. Never touches other worlds.
  public func loadSample() {
    perform {
      if let existing = try store.worlds().first(where: { $0.demo }) {
        switchWorld(existing.id)
        return
      }
      let w = try store.createWorld(
        name: "Aster", description: "The drowned world · sample", demo: true)
      let entity: (String, String, String) throws -> LoreRecord = { title, category, body in
        try self.store.createRecord(
          worldID: w.id, title: title, body: body, kind: "entity", category: category)
      }
      let city = try entity(
        "The Drowned City", "Places",
        "A harbour capital lost beneath the sea. Its lamps still burn under the glass.")
      let tide = try entity(
        "The Remembering Tide", "Cosmology",
        "The belief that the sea keeps every memory surrendered to it, and returns them changed.")
      let oren = try entity(
        "Oren Ashe", "Characters",
        "Eldest of the Tidekeepers. He remembers a crossing no one else survived.")
      let power = try entity(
        "The art of remembrance", "Power systems",
        "Borrow a memory. Live the skill inside it.\n\nCost: one memory of your own.\nRestriction: a borrowed life cannot be changed."
      )
      let sea = try entity(
        "The Glass Sea", "Places",
        "At dawn, the water becomes a dark mirror. The drowned city remains visible beneath it until the first tide returns."
      )
      let keepers = try entity(
        "Tidekeepers", "Factions", "A coastal order responsible for safe passage.")
      let mira = try entity(
        "Mira Vale", "Characters", "A cartographer tracing places that do not stay still.")
      _ = try store.createRecord(
        worldID: w.id, title: "What does the glass keep?",
        body: "What if the glass preserves the memory of everyone who has crossed it?",
        kind: "capture", category: "Ideas")
      let crossing = try store.createRecord(
        worldID: w.id, title: "Crossing the Glass Sea",
        body:
          "At dawn, the sea remembers how to be solid.\n\nFor a few quiet hours, the water becomes a single sheet of dark glass. Beneath it, the lights of the drowned city still burn.\n\nThose who cross\n\nMira Vale is the only cartographer who has walked beyond the old bell tower. The Tidekeepers guide travelers back before the glass becomes water.",
        category: "Places")
      for (a, b, label) in [
        (mira, keepers, "guided by"), (mira, sea, "maps"), (keepers, power, "safeguards"),
        (oren, keepers, "leads"), (sea, city, "covers"), (power, tide, "draws on"),
        (oren, mira, "mentors"),
      ] { _ = try store.addRelation(worldID: w.id, source: a.id, target: b.id, label: label) }
      for (source, target) in [(crossing, sea), (crossing, mira), (crossing, keepers)] {
        try store.linkRecord(worldID: w.id, source: source.id, target: target.id)
      }
      _ = try store.saveMetadata(
        worldID: w.id, id: mira.id, version: mira.version, tags: ["cartography", "protagonist"],
        aliases: ["The Mapmaker"])
      _ = try store.addEvent(
        worldID: w.id, title: "The drowning", date: "Before memory", source: city.id, order: 1)
      _ = try store.addEvent(
        worldID: w.id, title: "The coastal order is founded", date: "First tide-year",
        source: keepers.id, order: 2)
      _ = try store.addEvent(worldID: w.id, title: "The first crossing", date: "", source: mira.id)
      var document = CanvasDocument()
      let artwork = Self.sampleArtwork()
      let positions = [(-370.0, 20.0), (0.0, -160.0), (390.0, 30.0), (0.0, 170.0)]
      for (index, record) in [mira, keepers, sea, power].enumerated() {
        var card = CanvasCard(text: record.title, recordID: record.id)
        card.width = 300
        card.x = positions[index].0
        card.y = positions[index].1
        if record.id == sea.id { card.image = artwork?.base64EncodedString() }
        if record.id == mira.id {
          card.image = StudioArtwork.cartographer.data?.base64EncodedString()
        }
        document.cards.append(card)
      }
      _ = try store.saveBoard(
        worldID: w.id, name: "The first crossing", kind: "canvas",
        content: String(decoding: try JSONEncoder().encode(document), as: UTF8.self))
      if let artwork {
        try store.setPreference("world-cover:\(w.id)", value: artwork.base64EncodedString())
      }
      switchWorld(w.id)
    }
  }
}
