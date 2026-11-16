import AppKit
import Foundation
import Testing

@testable import SynthesisCore

struct MarkdownExportTests {
  @Test func standaloneExportHasSafeNameMetadataAndSections() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Export")
    let parent = try store.createRecord(
      worldID: world.id, title: "Mira / Vale", body: "# History\n\nA mapmaker.", kind: "entity")
    let child = try store.createRecordSection(
      worldID: world.id, parentID: parent.id, title: "Motives", body: "Find her sister.")
    let file = try store.exportRecordMarkdown(worldID: world.id, recordID: parent.id)
    #expect(file.filename == "Mira - Vale.md")
    #expect(
      file.content.contains("# History") && file.content.contains("tags: []")
        && file.content.contains("aliases: []"))
    #expect(
      file.content.contains("(#section-\(child.record.id))")
        && file.content.contains("Find her sister."))
    // Legacy untitled records still export safely; normal creation requires a title.
    try store.db.execute("UPDATE records SET title='' WHERE id=?", [parent.id])
    let untitled = try store.exportRecordMarkdown(worldID: world.id, recordID: parent.id)
    #expect(untitled.filename == "Untitled.md" && untitled.content.contains("# Untitled"))
    #expect(
      try store.exportMarkdown(worldID: world.id).contains { $0.path.hasSuffix("/Untitled.md") })
  }
  @Test func bothExportsPreserveNativeFormatting() throws {
    let store = try WorkspaceStore(path: ":memory:")
    let world = try store.createWorld(name: "Rich export")
    let body = "Origins\nA bold promise.\nRead the ledger"
    let rich = NSMutableAttributedString(
      string: body, attributes: [.font: NSFont.systemFont(ofSize: 16)])
    rich.addAttribute(
      .font, value: NSFont.boldSystemFont(ofSize: 22), range: NSRange(location: 0, length: 7))
    rich.addAttribute(
      .font, value: NSFont.boldSystemFont(ofSize: 16), range: (body as NSString).range(of: "bold"))
    rich.addAttribute(
      .link, value: URL(string: "https://example.com/ledger")!,
      range: (body as NSString).range(of: "ledger"))
    let rtf = try rich.data(
      from: NSRange(location: 0, length: rich.length),
      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    ).base64EncodedString()
    let page = try store.createRecord(worldID: world.id, title: "Origins", body: body)
    _ = try store.saveRecord(
      worldID: world.id, id: page.id, version: page.version, title: page.title, body: body, rtf: rtf
    )
    let single = try store.exportRecordMarkdown(worldID: world.id, recordID: page.id).content
    let worldFile = try #require(
      store.exportMarkdown(worldID: world.id).first { $0.path == "Documents/Origins.md" }
    ).content
    for content in [single, worldFile] {
      #expect(content.contains("## Origins"))
      #expect(content.contains("**bold**"))
      #expect(content.contains("[ledger](https://example.com/ledger)"))
    }
  }
}
