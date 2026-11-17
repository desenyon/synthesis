import Foundation
import Testing

@testable import SynthesisCore

struct ImageGenerationTests {
  static let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13]

  func standIn(_ body: String) throws -> (path: String, folder: URL, home: URL) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
      "image-test-\(UUID().uuidString)")
    let home = folder.appendingPathComponent("codex-home")
    try FileManager.default.createDirectory(
      at: home.appendingPathComponent("generated_images/old"), withIntermediateDirectories: true)
    // An older image from another session must never be picked up.
    let old = home.appendingPathComponent("generated_images/old/earlier.png")
    try Data(Self.png + [1]).write(to: old)
    try FileManager.default.setAttributes(
      [.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: old.path)
    let url = folder.appendingPathComponent("fake")
    try
      "#!/bin/sh\nLOG='\(folder.path)'\nif [ \"$1\" = login ]; then echo 'Logged in using ChatGPT'; exit 0; fi\n\(body)\n"
      .write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return (url.path, folder, home)
  }

  @Test func importsOnlyTheImageWrittenDuringThisRequest() async throws {
    let fake = try standIn(
      """
      printf '%s\\n' "$@" > "$LOG/args"
      cat > "$LOG/prompt"
      env > "$LOG/env"
      mkdir -p "$CODEX_HOME/generated_images/session"
      printf '\\211PNG\\r\\n\\032\\n\\000\\000\\000\\rnew' > "$CODEX_HOME/generated_images/session/ig_1.png"
      echo '{"type":"item.completed","item":{"type":"agent_message","text":"Done."}}'
      """)
    let home = fake.home
    let generator = CodexImageGenerator(executable: { fake.path }, codexHome: { home })
    let data = try await generator.generate("A drowned lighthouse at dawn")
    #expect(String(decoding: data.suffix(3), as: UTF8.self) == "new")
    let args = try String(contentsOf: fake.folder.appendingPathComponent("args"), encoding: .utf8)
    #expect(args.contains("image_generation\n") && args.contains("--enable\nimage_generation"))
    #expect(args.contains("--disable\nshell_tool") && args.contains("read-only"))
    let prompt = try String(
      contentsOf: fake.folder.appendingPathComponent("prompt"), encoding: .utf8)
    #expect(prompt.contains("A drowned lighthouse at dawn"))
    let env = try String(contentsOf: fake.folder.appendingPathComponent("env"), encoding: .utf8)
    #expect(env.contains("CODEX_HOME=\(home.path)"))
    #expect(!env.contains("OPENAI_API_KEY"))
  }

  @Test func refusesWhenNothingNewOrNotAnImage() async throws {
    let silent = try standIn(
      "cat > /dev/null\necho '{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":\"I cannot.\"}}'"
    )
    let none = CodexImageGenerator(executable: { silent.path }, codexHome: { silent.home })
    await #expect(throws: SynthesisError.self) { try await none.generate("A map") }

    let fakeFile = try standIn(
      "cat > /dev/null\nmkdir -p \"$CODEX_HOME/generated_images/s\"\necho 'not an image' > \"$CODEX_HOME/generated_images/s/x.png\""
    )
    let bad = CodexImageGenerator(executable: { fakeFile.path }, codexHome: { fakeFile.home })
    await #expect(throws: SynthesisError.self) { try await bad.generate("A map") }
    await #expect(throws: SynthesisError.self) { try await bad.generate("   ") }
  }

  @Test func chatStillDisablesImageGeneration() throws {
    let source = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/SynthesisCore/HarnessTransport.swift"), encoding: .utf8)
    #expect(source.contains("\"--disable\", \"image_generation\""))
  }
}
