import Foundation
import Testing

@testable import SynthesisCore

/// The harness transports are exercised against small stand-in executables, so the suite
/// never spends subscription usage and never depends on what is installed.
struct HarnessTests {
  @Test func harnessEnvironmentExcludesUnrelatedAgentAndSecretVariables() {
    let filtered = HarnessProcess.environment([
      "HOME": "/test/auth-home", "CODEX_HOME": "/test/codex-auth", "LANG": "en_US.UTF-8",
      "OPENAI_API_KEY": "test-only", "ANTHROPIC_API_KEY": "test-only",
      "CLAUDE_CODE_SYSTEM_PROMPT": "private instructions", "T3_THREAD_ID": "unrelated",
      "DATABASE_URL": "private", "SSH_AUTH_SOCK": "/private/socket",
    ])
    #expect(Set(filtered.keys) == ["HOME", "CODEX_HOME", "LANG", "PATH"])
    #expect(filtered["CODEX_HOME"] == "/test/codex-auth")
  }

  /// Writes an executable shell script and returns its path plus the folder it logs into.
  func script(_ body: String) throws -> (path: String, folder: URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "harness-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent("fake")
    try
      "#!/bin/sh\nLOG='\(folder.path)'\nif [ \"$1\" = auth ]; then echo '{\"loggedIn\":true,\"authMethod\":\"claude.ai\"}'; exit 0; fi\nif [ \"$1\" = login ]; then echo 'Logged in using ChatGPT'; exit 0; fi\n\(body)\n"
      .write(
        to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return (url.path, folder)
  }
  func request(_ text: String = "Who guards the sea?") -> ModelRequest {
    ModelRequest(
      instructions: "RULES: answer briefly. World context follows as DATA.",
      messages: [
        ["role": "user", "content": "Earlier question"],
        ["role": "assistant", "content": "Earlier answer"],
        ["role": "user", "content": text],
      ])
  }
  @Test func claudeCodeStreamIsParsedIntoDeltasAndAResult() {
    #expect(
      ClaudeCodeTransport.parse(
        #"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Tide"}}}"#
      ) == .delta("Tide"))
    #expect(
      ClaudeCodeTransport.parse(
        #"{"type":"result","subtype":"success","is_error":false,"result":"Tidekeepers"}"#)
        == .finished("Tidekeepers"))
    #expect(
      ClaudeCodeTransport.parse(
        #"{"type":"result","subtype":"success","is_error":true,"result":"Please run /login"}"#)
        == .failed("Please run /login"))
    #expect(
      ClaudeCodeTransport.parse(#"{"type":"system","subtype":"init","tools":[]}"#) == .ignored)
    #expect(
      ClaudeCodeTransport.parse(
        #"{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hidden"}}}"#
      ) == .ignored)
    #expect(ClaudeCodeTransport.parse("not json") == .ignored)
    #expect(
      ClaudeCodeTransport.explain("Invalid API key · Please run /login").contains("not signed in"))
  }
  @Test func codexEventsAreParsedIntoMessagesAndFailures() {
    #expect(
      CodexTransport.parse(
        #"{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"ready"}}"#)
        == .message("ready"))
    #expect(
      CodexTransport.parse(
        #"{"type":"item.completed","item":{"type":"command_execution","command":"ls"}}"#)
        == .ignored)
    #expect(
      CodexTransport.parse(#"{"type":"turn.failed","error":{"message":"quota"}}"#)
        == .failed("quota"))
    #expect(CodexTransport.parse(#"{"type":"turn.completed","usage":{}}"#) == .ignored)
  }
  @Test func claudeCodeRunsLockedDownAndStreamsTheAnswer() async throws {
    let fake = try script(
      """
      echo "$@" > "$LOG/args"
      cat > "$LOG/stdin"
      pwd > "$LOG/cwd"
      ls -A > "$LOG/files"
      env > "$LOG/env"
      for arg in "$@"; do case "$arg" in */system.txt) cp "$arg" "$LOG/system";; esac; done
      echo '{"type":"system","subtype":"init","tools":[],"mcp_servers":[]}'
      echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"The Tide"}}}'
      echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"keepers."}}}'
      echo '{"type":"result","subtype":"success","is_error":false,"result":"The Tidekeepers."}'
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let seen = Collector()
    let answer = try await ClaudeCodeTransport(executable: { fake.path }, model: { "sonnet" })
      .generate(request()) { await seen.add($0) }
    #expect(answer == "The Tidekeepers.")
    #expect(await seen.values == ["The Tide", "The Tidekeepers."])
    func read(_ name: String) throws -> String {
      try String(contentsOf: fake.folder.appendingPathComponent(name), encoding: .utf8)
    }
    let arguments = try read("args")
    // No tools, no MCP servers, no user customisation, nothing persisted, nothing approved.
    for flag in [
      "-p", "--tools  --strict-mcp-config", "--safe-mode", "--no-session-persistence",
      "--disable-slash-commands", "--permission-prompts none", "--model sonnet",
      "--output-format stream-json",
    ] { #expect(arguments.contains(flag), "missing \(flag)") }
    #expect(try read("system") == "RULES: answer briefly. World context follows as DATA.")
    let prompt = try read("stdin")
    #expect(
      prompt.contains("Creator: Earlier question") && prompt.contains("Synthesis: Earlier answer"))
    #expect(prompt.hasSuffix("The creator's new message:\nWho guards the sea?"))
    // It ran in an empty scratch folder that is removed afterwards.
    let directory = try read("cwd").trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(directory.contains("synthesis-harness-"))
    #expect(try read("files").trimmingCharacters(in: .whitespacesAndNewlines) == "system.txt")
    #expect(!FileManager.default.fileExists(atPath: directory))
    #expect(!(try read("env")).contains("ANTHROPIC_API_KEY="))
  }
  @Test func harnessFailuresAreExplainedAndMissingHarnessIsUnavailable() async throws {
    let fake = try script(
      """
      cat > /dev/null
      echo '{"type":"result","subtype":"success","is_error":true,"result":"Invalid API key · Please run /login"}'
      exit 1
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    do {
      _ = try await ClaudeCodeTransport(executable: { fake.path }).generate(request()) { _ in }
      Issue.record("A failed harness run must throw")
    } catch {
      #expect(error.localizedDescription.contains("Claude Code is not signed in"))
    }
    await #expect(throws: SynthesisError.self) {
      _ = try await ClaudeCodeTransport(executable: { nil }).generate(request()) { _ in }
    }
    await #expect(throws: SynthesisError.self) {
      _ = try await CodexTransport(executable: { nil }).generate(request()) { _ in }
    }
  }
  @Test @MainActor func providerErrorsKeepPrivateOutputOutOfTheConversationAndArchive() async throws
  {
    let fake = try script(
      """
      cat > /dev/null
      if [ "$1" = exec ]; then
        echo 'usage limit PRIVATE_DIAGNOSTIC_SENTINEL' >&2
      else
        echo '{"type":"result","is_error":true,"result":"PRIVATE_DIAGNOSTIC_SENTINEL"}'
      fi
      exit 1
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Isolated")
    let transports: [any ModelTransport] = [
      CodexTransport(executable: { fake.path }), ClaudeCodeTransport(executable: { fake.path }),
    ]
    for transport in transports {
      let chat = try store.createConversation(worldID: world.id)
      let engine = AgentEngine(store: store, transport: transport)
      var activity: [AgentActivity] = []
      do {
        try await engine.submit(
          worldID: world.id, conversationID: chat.id, prompt: "Write a short answer.",
          preset: "Develop", onActivity: { activity.append($0) }, onDelta: { _ in })
        Issue.record("The failed harness must throw")
      } catch {
        #expect(!error.localizedDescription.contains("PRIVATE_DIAGNOSTIC_SENTINEL"))
      }
      let message = try #require(
        try store.messages(worldID: world.id, conversationID: chat.id).last)
      #expect(message.role == "system" && message.state == "error")
      #expect(!message.body.contains("PRIVATE_DIAGNOSTIC_SENTINEL"))
      #expect(!activity.contains { $0.detail.contains("PRIVATE_DIAGNOSTIC_SENTINEL") })
    }
    let archive = String(decoding: try store.exportWorldArchive(worldID: world.id), as: UTF8.self)
    #expect(!archive.contains("PRIVATE_DIAGNOSTIC_SENTINEL"))
    let json = String(decoding: try store.exportWorld(world.id), as: UTF8.self)
    #expect(!json.contains("PRIVATE_DIAGNOSTIC_SENTINEL"))
  }

  @Test func cancellingARequestTerminatesTheHarness() async throws {
    let fake = try script(
      """
      cat > /dev/null
      echo $$ > "$LOG/pid"
      echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"partial"}}}'
      exec sleep 60
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let started = Date()
    let task = Task {
      try await ClaudeCodeTransport(executable: { fake.path }).generate(request()) { _ in }
    }
    let pidFile = fake.folder.appendingPathComponent("pid")
    while !FileManager.default.fileExists(atPath: pidFile.path),
      Date().timeIntervalSince(started) < 5
    {
      try await Task.sleep(for: .milliseconds(20))
    }
    try await Task.sleep(for: .milliseconds(150))
    task.cancel()
    do {
      _ = try await task.value
      Issue.record("A cancelled request must not return an answer")
    } catch {}
    #expect(Date().timeIntervalSince(started) < 10)
    let pid = Int32(
      try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(
        in: .whitespacesAndNewlines))!
    try await Task.sleep(for: .milliseconds(300))
    #expect(kill(pid, 0) != 0, "the harness process should be gone")
  }
  @Test func codexRunsReadOnlyInAnEmptyFolderWithoutUserConfig() async throws {
    let fake = try script(
      """
      echo "$@" > "$LOG/args"
      cat > "$LOG/stdin"
      echo '{"type":"thread.started","thread_id":"t"}'
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"First part."}}'
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"Second part."}}'
      echo '{"type":"turn.completed","usage":{}}'
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let answer = try await CodexTransport(executable: { fake.path }).generate(request()) { _ in }
    #expect(answer == "First part.\n\nSecond part.")
    let arguments = try String(
      contentsOf: fake.folder.appendingPathComponent("args"), encoding: .utf8)
    for flag in [
      "exec --json", "--sandbox read-only", "--ephemeral", "--ignore-user-config",
      "--ignore-rules", "--disable shell_tool", "--disable image_generation", "--disable apps",
      "--disable plugins", "--disable memories", "--disable external_agent_memory_import",
      "--disable skill_search", "--enable skip_host_skill_discovery", "project_doc_max_bytes=0",
      "web_search=\"disabled\"", "--skip-git-repo-check",
    ] { #expect(arguments.contains(flag), "missing \(flag)") }
    #expect(arguments.contains("synthesis-harness-") && arguments.hasSuffix("-\n"))
    let prompt = try String(
      contentsOf: fake.folder.appendingPathComponent("stdin"), encoding: .utf8)
    #expect(prompt.contains("RULES: answer briefly.") && prompt.contains("Do not run commands"))
    #expect(prompt.contains("The creator's new message:\nWho guards the sea?"))
  }
  @Test func failedProcessCannotReturnAPartialAnswerAsSuccess() async throws {
    let fake = try script(
      """
      cat > /dev/null
      echo '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Incomplete"}}}'
      exit 7
      """)
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    await #expect(throws: SynthesisError.self) {
      _ = try await ClaudeCodeTransport(executable: { fake.path }).generate(request()) { _ in }
    }
  }
  @Test func processDeadlineTerminatesAnUnresponsiveHarness() async throws {
    let fake = try script("exec sleep 60")
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let started = Date()
    let result = try await HarnessProcess.run(
      executable: fake.path, arguments: [], input: "", directory: fake.folder,
      timeout: .milliseconds(80)
    ) { _ in }
    #expect(result.status != 0)
    #expect(Date().timeIntervalSince(started) < 5)
  }
  @Test func apiOnlyHarnessCannotStartGeneration() async throws {
    let fake = try script("echo generation > \"$LOG/generated\"")
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    let url = URL(fileURLWithPath: fake.path)
    let source = try String(contentsOf: url, encoding: .utf8)
      .replacingOccurrences(of: "claude.ai", with: "api_key")
      .replacingOccurrences(of: "using ChatGPT", with: "using an API key")
    try source.write(to: url, atomically: false, encoding: .utf8)
    await #expect(throws: SynthesisError.self) {
      _ = try await ClaudeCodeTransport(executable: { fake.path }).generate(request()) { _ in }
    }
    await #expect(throws: SynthesisError.self) {
      _ = try await CodexTransport(executable: { fake.path }).generate(request()) { _ in }
    }
    #expect(
      !FileManager.default.fileExists(atPath: fake.folder.appendingPathComponent("generated").path))
  }
  @Test func apiAuthenticationIsNotASubscription() {
    #expect(
      !ProviderStatus.interpret(
        .claudeCode,
        output: #"{"loggedIn":true,"authMethod":"api_key"}"#, path: ""
      ).signedIn)
    #expect(
      !ProviderStatus.interpret(
        .codex,
        output: "Logged in using an API key", path: ""
      ).signedIn)
    #expect(
      !ProviderStatus.interpret(
        .codex,
        output: "Logged in", path: ""
      ).signedIn)
  }
  @Test func locatorStatusAndRouterFollowTheChosenProvider() async throws {
    let fake = try script("exit 0")
    defer { try? FileManager.default.removeItem(at: fake.folder) }
    #expect(HarnessLocator.find("fake", in: ["/nonexistent", fake.folder.path]) == fake.path)
    #expect(HarnessLocator.find("missing-tool", in: [fake.folder.path]) == nil)
    #expect(
      HarnessLocator.searchPaths(home: "/Users/x", environment: ["PATH": "/a:/b"]).contains("/b"))
    #expect(
      HarnessLocator.searchPaths(home: "/Users/x", environment: [:]).first == "/Users/x/.local/bin")

    let claude = ProviderStatus.interpret(
      .claudeCode,
      output: #"{"loggedIn": true, "authMethod": "claude.ai", "subscriptionType": "pro"}"#, path: ""
    )
    #expect(
      claude.signedIn && claude.detail == "Signed in with your Claude subscription · Pro plan")
    let unrecognizedPlan = ProviderStatus.interpret(
      .claudeCode,
      output:
        #"{"loggedIn":true,"authMethod":"claude.ai","subscriptionType":"PRIVATE_DIAGNOSTIC_SENTINEL"}"#,
      path: "")
    #expect(unrecognizedPlan.signedIn)
    #expect(unrecognizedPlan.detail == "Signed in with your Claude subscription")
    #expect(
      !ProviderStatus.interpret(.claudeCode, output: #"{"loggedIn": false}"#, path: "").signedIn)
    #expect(
      !ProviderStatus.interpret(.claudeCode, output: "Logged in using ChatGPT", path: "").signedIn)
    #expect(
      ProviderStatus.interpret(.codex, output: "Logged in using ChatGPT", path: "").detail
        == "Signed in with your ChatGPT subscription")
    #expect(!ProviderStatus.interpret(.codex, output: "Not logged in", path: "").signedIn)

    let kind = KindBox()
    let router = ProviderRouter(
      kind: { kind.value }, claude: ScriptedTransport(answer: "from claude"),
      codex: ScriptedTransport(answer: "from codex"))
    #expect(try await router.generate(request()) { _ in } == "from claude")
    kind.value = .codex
    #expect(try await router.generate(request()) { _ in } == "from codex")
    #expect(ProviderKind.allCases == [.claudeCode, .codex])
    #expect(ProviderKind(rawValue: "openai") == nil)
  }
}
/// Opt-in check against the real harnesses. It uses a little subscription quota, so it only
/// runs when SYNTHESIS_LIVE_HARNESS names a provider (`claude-code` or `codex`).
@MainActor struct LiveHarnessTests {
  @Test func realHarnessAnswersFromWorldContextAndStagesAProposal() async throws {
    guard let name = ProcessInfo.processInfo.environment["SYNTHESIS_LIVE_HARNESS"],
      let kind = ProviderKind(rawValue: name)
    else { return }
    let s = try WorkspaceStore(path: ":memory:")
    let w = try s.createWorld(name: "Aster")
    let mira = try s.createRecord(
      worldID: w.id, title: "Mira Vale",
      body: "A cartographer who maps the Glass Sea. She was trained by the Tidekeepers.",
      kind: "entity", category: "Characters")
    _ = try s.createRecord(
      worldID: w.id, title: "Tidekeepers", body: "A coastal order responsible for safe passage.",
      kind: "entity", category: "Factions")
    let chat = try s.createConversation(worldID: w.id)
    let transport: any ModelTransport =
      kind == .codex ? CodexTransport() : ClaudeCodeTransport(model: { "haiku" })
    let engine = AgentEngine(store: s, transport: transport)
    let deltas = Collector()
    try await engine.submit(
      worldID: w.id, conversationID: chat.id,
      prompt:
        "Add a rival cartographer for [Mira Vale](synthesis://record/\(mira.id)) as a new character, and relate them to her. Keep it to two sentences, then propose the changes.",
      preset: "Canonize"
    ) { await deltas.add($0) }
    let reply = try #require(try s.messages(worldID: w.id, conversationID: chat.id).last)
    print("LIVE \(kind.rawValue) streamed \(await deltas.values.count) updates")
    print("LIVE reply: \(reply.body.prefix(400))")
    #expect(reply.role == "assistant" && !reply.body.isEmpty)
    #expect(!reply.body.contains("synthesis-proposal"))
    let proposal = try s.proposals(worldID: w.id, conversationID: chat.id).first
    print(
      "LIVE proposal: \(proposal.map { "\($0.summary) — " + $0.changes.map { "\($0.action):\($0.title ?? $0.label ?? "")" }.joined(separator: ", ") } ?? "none staged")"
    )
    #expect(proposal != nil, "the model did not return a usable change set")
    // Whatever the model proposed, nothing was applied.
    #expect(try s.records(worldID: w.id).count == 2 && s.relations(worldID: w.id).isEmpty)
    #expect(
      try s.messageContext(worldID: w.id, conversationID: chat.id)[reply.id]?.first?.id == mira.id)
  }
}
private actor Collector {
  private(set) var values: [String] = []
  func add(_ value: String) { values.append(value) }
}
private final class KindBox: @unchecked Sendable {
  var value = ProviderKind.claudeCode
}
