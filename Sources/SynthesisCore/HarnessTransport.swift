import Foundation

/// How Synthesis reaches a model. The default is a local agent harness that the creator has
/// already signed in to with their subscription. There is no direct API transport.
public enum ProviderKind: String, CaseIterable, Sendable, Identifiable {
  case claudeCode = "claude-code"
  case codex
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .claudeCode: return "Claude Code"
    case .codex: return "Codex"
    }
  }
  /// Who receives the message and world context when this provider is used.
  public var recipient: String {
    switch self {
    case .claudeCode: return "Anthropic, through Claude Code on this Mac"
    case .codex: return "OpenAI, through Codex on this Mac"
    }
  }
  var executableName: String {
    switch self {
    case .claudeCode: return "claude"
    case .codex: return "codex"
    }
  }
}

/// Finds a harness executable. Apps launched from Finder get a minimal PATH, so the usual
/// install locations are checked directly.
public enum HarnessLocator {
  public static func searchPaths(
    home: String = NSHomeDirectory(),
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String] {
    var paths = [
      "\(home)/.local/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin",
      "\(home)/.npm-global/bin", "\(home)/.bun/bin", "\(home)/.volta/bin", "\(home)/bin",
    ]
    let nvm = "\(home)/.nvm/versions/node"
    if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvm) {
      paths += versions.sorted().reversed().map { "\(nvm)/\($0)/bin" }
    }
    paths += (environment["PATH"] ?? "").split(separator: ":").map(String.init)
    var seen = Set<String>()
    return paths.filter { seen.insert($0).inserted }
  }
  public static func find(_ name: String, in paths: [String] = searchPaths()) -> String? {
    paths.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
  }
  public static func find(_ kind: ProviderKind) -> String? {
    find(kind.executableName)
  }
}

/// Runs a harness process, feeding it the prompt on standard input and reading its output
/// line by line. Cancelling the surrounding task terminates the process.
enum HarnessProcess {
  static func environment(_ inherited: [String: String]) -> [String: String] {
    var result = inherited.filter { key, _ in
      ["HOME", "USER", "LOGNAME", "TMPDIR", "LANG", "LC_ALL", "CODEX_HOME"].contains(key)
    }
    result["PATH"] = HarnessLocator.searchPaths().joined(separator: ":")
    return result
  }
  static func run(
    executable: String, arguments: [String], input: String, directory: URL,
    timeout: Duration = .seconds(180), extraEnvironment: [String: String] = [:],
    onLine: @escaping @Sendable (String) async throws -> Void
  ) async throws -> (status: Int32, errors: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = directory
    // Authentication stays with the subscription CLI. Never inherit arbitrary shell,
    // editor, project, prompt, API or agent-session variables into the model process.
    process.environment = environment(ProcessInfo.processInfo.environment).merging(
      extraEnvironment.filter { $0.key == "CODEX_HOME" }, uniquingKeysWith: { _, new in new })
    let stdin = Pipe()
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = stderr
    let exits = AsyncStream<Int32> { continuation in
      process.terminationHandler = { completed in
        continuation.yield(completed.terminationStatus)
        continuation.finish()
      }
    }
    try Task.checkCancellation()
    try process.run()
    let deadline = Task {
      try? await Task.sleep(for: timeout)
      if !Task.isCancelled { Self.stop(process) }
    }
    defer { deadline.cancel() }
    return try await withTaskCancellationHandler {
      async let errors: Data = Task.detached {
        stderr.fileHandleForReading.readDataToEndOfFile()
      }.value
      Task.detached {
        stdin.fileHandleForWriting.write(Data(input.utf8))
        try? stdin.fileHandleForWriting.close()
      }
      do {
        for try await line in stdout.fileHandleForReading.bytes.lines {
          try Task.checkCancellation()
          try await onLine(line)
        }
      } catch {
        Self.stop(process)
        throw error
      }
      var status: Int32 = -1
      for await value in exits {
        status = value
        break
      }
      try Task.checkCancellation()
      let text = String(decoding: await errors, as: UTF8.self)
      return (status, String(text.suffix(600)))
    } onCancel: {
      Self.stop(process)
    }
  }
  private static func stop(_ process: Process) {
    guard process.isRunning else { return }
    process.terminate()
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
      if process.isRunning { kill(process.processIdentifier, SIGKILL) }
    }
  }
  /// Empty scratch directory so the harness has no project files to read.
  static func scratch() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "synthesis-harness-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return url
  }
  /// One prompt holding the conversation so far and the creator's new message.
  static func transcript(_ messages: [[String: String]]) -> String {
    guard let last = messages.last else { return "" }
    let earlier = messages.dropLast().map {
      "\($0["role"] == "assistant" ? "Synthesis" : "Creator"): \($0["content"] ?? "")"
    }
    let history =
      earlier.isEmpty
      ? ""
      : "<conversation_so_far>\n\(earlier.joined(separator: "\n\n"))\n</conversation_so_far>\n\n"
    return history + "The creator's new message:\n" + (last["content"] ?? "")
  }
}

/// Claude Code in headless mode with every tool, MCP server, plugin and settings file disabled:
/// it can only read the prompt and write text. Sign-in belongs to Claude Code itself.
public struct ClaudeCodeTransport: ModelTransport {
  public let executable: @Sendable () -> String?
  public let model: @Sendable () -> String
  public init(
    executable: @escaping @Sendable () -> String? = { HarnessLocator.find(.claudeCode) },
    model: @escaping @Sendable () -> String = { "" }
  ) {
    self.executable = executable
    self.model = model
  }
  public enum Event: Equatable {
    case delta(String)
    case finished(String)
    case failed(String)
    case ignored
  }
  /// Interprets one line of `--output-format stream-json` output.
  public static func parse(_ line: String) -> Event {
    guard let data = line.data(using: .utf8),
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return .ignored }
    switch object["type"] as? String {
    case "stream_event":
      guard let event = object["event"] as? [String: Any],
        event["type"] as? String == "content_block_delta",
        let delta = event["delta"] as? [String: Any], delta["type"] as? String == "text_delta",
        let text = delta["text"] as? String
      else { return .ignored }
      return .delta(text)
    case "result":
      let text = object["result"] as? String ?? ""
      if object["is_error"] as? Bool == true || (object["subtype"] as? String ?? "") != "success" {
        return .failed(text.isEmpty ? (object["subtype"] as? String ?? "unknown error") : text)
      }
      return .finished(text)
    default: return .ignored
    }
  }
  static func explain(_ message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("login") || lower.contains("api key") || lower.contains("authenticat") {
      return
        "Claude Code is not signed in. Open Terminal, run `claude`, sign in with your subscription, then send again. Your message is saved."
    }
    if lower.contains("limit") {
      return "Claude Code reports a usage limit. Check your subscription allowance and send again."
    }
    // Error events and stderr can echo a prompt, credentials, or private paths.
    return "Claude Code could not finish this response. Your message is saved. Try again."
  }
  public func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    guard let path = executable() else { throw SynthesisError.unavailable }
    let signIn = await ProviderStatus.check(.claudeCode, executable: path)
    try Task.checkCancellation()
    guard signIn.signedIn else {
      throw SynthesisError.invalid("Subscription sign-in required. " + signIn.detail)
    }
    let directory = try HarnessProcess.scratch()
    defer { try? FileManager.default.removeItem(at: directory) }
    let rules = directory.appendingPathComponent("system.txt")
    try request.instructions.write(to: rules, atomically: true, encoding: .utf8)
    var arguments = [
      "-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
      "--system-prompt-file", rules.path, "--tools", "", "--strict-mcp-config",
      "--disable-slash-commands", "--no-session-persistence", "--safe-mode",
      "--permission-prompts", "none",
    ]
    let chosen = model().trimmingCharacters(in: .whitespacesAndNewlines)
    if !chosen.isEmpty { arguments += ["--model", chosen] }
    let state = HarnessState()
    let outcome = try await HarnessProcess.run(
      executable: path, arguments: arguments,
      input: HarnessProcess.transcript(request.messages), directory: directory
    ) { line in
      switch Self.parse(line) {
      case .delta(let text): await onDelta(await state.append(text))
      case .finished(let text): await state.finish(text)
      case .failed(let message): await state.fail(message)
      case .ignored: break
      }
    }
    if let failure = await state.failure { throw SynthesisError.invalid(Self.explain(failure)) }
    let answer = await state.answer
    guard outcome.status == 0 else {
      throw SynthesisError.invalid(
        Self.explain(outcome.errors.isEmpty ? "exit \(outcome.status)" : outcome.errors))
    }
    return answer
  }
}

/// Codex in non-interactive mode: read-only sandbox, empty working directory, no user config,
/// rules, apps or plugins. Sign-in belongs to Codex itself.
public struct CodexTransport: ModelTransport {
  public let executable: @Sendable () -> String?
  public let model: @Sendable () -> String
  public init(
    executable: @escaping @Sendable () -> String? = { HarnessLocator.find(.codex) },
    model: @escaping @Sendable () -> String = { "" }
  ) {
    self.executable = executable
    self.model = model
  }
  public enum Event: Equatable {
    case message(String)
    case failed(String)
    case ignored
  }
  /// Interprets one line of `codex exec --json` output.
  public static func parse(_ line: String) -> Event {
    guard let data = line.data(using: .utf8),
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return .ignored }
    switch object["type"] as? String {
    case "item.completed":
      guard let item = object["item"] as? [String: Any], item["type"] as? String == "agent_message",
        let text = item["text"] as? String
      else { return .ignored }
      return .message(text)
    case "error":
      return .failed(object["message"] as? String ?? "unknown error")
    case "turn.failed":
      let error = object["error"] as? [String: Any]
      return .failed(error?["message"] as? String ?? "the turn failed")
    default: return .ignored
    }
  }
  static func explain(_ message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("login") || lower.contains("logged") || lower.contains("auth") {
      return
        "Codex is not signed in. Open Terminal, run `codex login`, sign in with your subscription, then send again. Your message is saved."
    }
    if lower.contains("usage limit") || lower.contains("quota") {
      return "Codex reports a usage limit. Check your subscription allowance and send again."
    }
    return "Codex could not finish this response. Your message is saved. Try again."
  }
  public func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    guard let path = executable() else { throw SynthesisError.unavailable }
    let signIn = await ProviderStatus.check(.codex, executable: path)
    try Task.checkCancellation()
    guard signIn.signedIn else {
      throw SynthesisError.invalid("Subscription sign-in required. " + signIn.detail)
    }
    let directory = try HarnessProcess.scratch()
    defer { try? FileManager.default.removeItem(at: directory) }
    var arguments = [
      "exec", "--json", "--sandbox", "read-only", "--skip-git-repo-check", "--ephemeral",
      "--ignore-user-config", "--ignore-rules", "--disable", "apps", "--disable", "plugins",
      "--disable", "browser_use", "--disable", "computer_use", "--disable", "shell_tool",
      "--disable", "image_generation", "--disable", "memories",
      "--disable", "external_agent_memory_import", "--disable", "skill_search",
      "--enable", "skip_host_skill_discovery", "-c", "project_doc_max_bytes=0",
      "-c", "web_search=\"disabled\"", "-C",
      directory.path,
    ]
    let chosen = model().trimmingCharacters(in: .whitespacesAndNewlines)
    if !chosen.isEmpty { arguments += ["-m", chosen] }
    arguments.append("-")
    // Codex has no system-prompt flag, so the operating rules lead the prompt.
    let prompt = """
      <operating_rules>
      Answer in Markdown as a writing collaborator. Do not run commands, read files or browse; everything you need is in this message.
      \(request.instructions)
      </operating_rules>

      \(HarnessProcess.transcript(request.messages))
      """
    let state = HarnessState()
    let outcome = try await HarnessProcess.run(
      executable: path, arguments: arguments, input: prompt, directory: directory
    ) { line in
      switch Self.parse(line) {
      case .message(let text): await onDelta(await state.append(text, separator: "\n\n"))
      case .failed(let message): await state.fail(message)
      case .ignored: break
      }
    }
    if let failure = await state.failure { throw SynthesisError.invalid(Self.explain(failure)) }
    let answer = await state.answer
    guard outcome.status == 0, !answer.isEmpty else {
      throw SynthesisError.invalid(
        Self.explain(outcome.errors.isEmpty ? "exit \(outcome.status)" : outcome.errors))
    }
    return answer
  }
}

private actor HarnessState {
  private(set) var answer = ""
  private(set) var failure: String?
  func append(_ text: String, separator: String = "") -> String {
    answer += (answer.isEmpty ? "" : separator) + text
    return answer
  }
  func finish(_ text: String) { if !text.isEmpty { answer = text } }
  func fail(_ message: String) { failure = message }
}

/// Sends each request to whichever provider the creator has chosen at that moment.
public struct ProviderRouter: ModelTransport {
  public let kind: @Sendable () -> ProviderKind
  public let claude: any ModelTransport
  public let codex: any ModelTransport
  public init(
    kind: @escaping @Sendable () -> ProviderKind, claude: any ModelTransport,
    codex: any ModelTransport
  ) {
    self.kind = kind
    self.claude = claude
    self.codex = codex
  }
  public func generate(_ request: ModelRequest, onDelta: @escaping @Sendable (String) async -> Void)
    async throws -> String
  {
    switch kind() {
    case .claudeCode: return try await claude.generate(request, onDelta: onDelta)
    case .codex: return try await codex.generate(request, onDelta: onDelta)
    }
  }
}

/// Sign-in state reported by a harness itself. Makes no model request.
public struct ProviderStatus: Equatable, Sendable {
  public var installed: Bool
  public var signedIn: Bool
  public var detail: String
  public static func check(_ kind: ProviderKind) async -> ProviderStatus {
    guard let path = HarnessLocator.find(kind) else {
      return ProviderStatus(
        installed: false, signedIn: false, detail: "\(kind.title) is not installed on this Mac")
    }
    return await check(kind, executable: path)
  }
  public static func check(_ kind: ProviderKind, executable path: String) async -> ProviderStatus {
    let output = OutputBuffer()
    guard let directory = try? HarnessProcess.scratch() else {
      return ProviderStatus(
        installed: true, signedIn: false, detail: "Cannot create a private sign-in check folder.")
    }
    defer { try? FileManager.default.removeItem(at: directory) }
    let result = try? await HarnessProcess.run(
      executable: path, arguments: kind == .claudeCode ? ["auth", "status"] : ["login", "status"],
      input: "", directory: directory, timeout: .seconds(8)
    ) { line in await output.add(line) }
    guard result?.status == 0 else {
      return ProviderStatus(
        installed: true, signedIn: false,
        detail: "Sign-in check failed. Open \(kind.title) and sign in with your subscription.")
    }
    let text = await output.text + (kind == .codex ? result?.errors ?? "" : "")
    return interpret(kind, output: text, path: path)
  }
  /// Reads the harness's own status output.
  public static func interpret(_ kind: ProviderKind, output: String, path: String)
    -> ProviderStatus
  {
    if kind == .claudeCode {
      let object = (try? JSONSerialization.jsonObject(with: Data(output.utf8))) as? [String: Any]
      guard object?["loggedIn"] as? Bool == true, object?["authMethod"] as? String == "claude.ai"
      else {
        return ProviderStatus(
          installed: true, signedIn: false, detail: "Not signed in — run `claude` in Terminal")
      }
      let plan: String
      switch (object?["subscriptionType"] as? String)?.lowercased() {
      case "pro": plan = " · Pro plan"
      case "max": plan = " · Max plan"
      case "team": plan = " · Team plan"
      case "enterprise": plan = " · Enterprise plan"
      default: plan = ""
      }
      return ProviderStatus(
        installed: true, signedIn: true,
        detail: "Signed in with your Claude subscription\(plan)")
    }
    let lower = output.lowercased()
    let signedIn =
      lower.contains("logged in") && lower.contains("chatgpt") && !lower.contains("not logged in")
      && !lower.contains("api key")
    return ProviderStatus(
      installed: true, signedIn: signedIn,
      detail: signedIn
        ? "Signed in with your ChatGPT subscription"
        : "Not signed in — run `codex login` in Terminal")
  }
}
private actor OutputBuffer {
  private(set) var text = ""
  func add(_ line: String) { text += line + "\n" }
}
