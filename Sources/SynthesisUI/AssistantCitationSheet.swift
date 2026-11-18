import SwiftUI
import SynthesisCore

struct AssistantCitationSheet: View {
  let source: AssistantCitationPassage
  let studio: Studio
  let close: () -> Void

  var body: some View {
    SheetScaffold(title: "Accepted passage", t: studio.t, close: close) {
      VStack(alignment: .leading, spacing: Space.sm) {
        Text(source.title).font(.studio(.control)).lineLimit(2)
          .accessibilityAddTraits(.isHeader)
        Text("Revision \(source.address.approvalVersion) · Passage \(source.address.passage + 1)")
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
        ScrollView {
          Text(verbatim: source.text).font(.studio(size: 14)).lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
        .frame(maxHeight: 250).padding(12)
        .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
      }
    } footer: {
      Spacer()
      Button("Open current source") {
        studio.perform {
          let record = try studio.store.record(
            worldID: source.address.worldID, id: source.address.recordID)
          studio.openRecord(record)
        }
        close()
      }.buttonStyle(QuietButton(t: studio.t))
    }
  }
}
