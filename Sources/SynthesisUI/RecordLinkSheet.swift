import SwiftUI
import SynthesisCore

/// The same relationship form is reachable from Graph, the native menu and the command palette.
struct RecordLinkSheet: View {
  @ObservedObject var studio: Studio
  @State var draft: RecordLinkDraft
  @State private var suggestions: [String] = []
  private var choices: [LoreRecord] {
    studio.records.filter {
      $0.worldID == draft.worldID && (draft.kind == .reference || $0.kind == "entity")
    }
  }
  private var valid: Bool { draft.worldID == studio.worldID && draft.isValid(records: choices) }
  private func close() {
    studio.recordLinkDraft = nil
    studio.sheet = nil
  }
  var body: some View {
    SheetScaffold(
      title: "Link records", subtitle: "Describe how two parts of your world connect.",
      t: studio.t, width: 520, close: close
    ) {
      if !draft.entitiesOnly {
        Picker("Link kind", selection: $draft.kind) {
          ForEach(RecordLinkKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
      }
      HStack(alignment: .bottom, spacing: 12) {
        RecordLinkChoice(title: "From", records: choices, selection: $draft.sourceID, t: studio.t)
        StudioIcon("arrow.right", size: 14).foregroundStyle(studio.t.muted).padding(.bottom, 10)
        RecordLinkChoice(
          title: "To", records: choices.filter { $0.id != draft.sourceID },
          selection: $draft.targetID, t: studio.t)
      }
      if draft.kind == .relationship {
        FormField(
          label: "Relationship", placeholder: "guided by, rules, born in…", text: $draft.label,
          t: studio.t, submit: { if valid { studio.saveRecordLink(draft) } })
        Toggle("Also describe the reverse relationship", isOn: $draft.reverse)
          .toggleStyle(.checkbox).font(.studio(.control))
        if draft.reverse {
          FormField(
            label: "Reverse relationship", placeholder: "guides, ruled by, birthplace of…",
            text: $draft.reverseLabel, t: studio.t,
            submit: { if valid { studio.saveRecordLink(draft) } })
        }
        if !suggestions.isEmpty {
          ScrollView(.horizontal) {
            HStack(spacing: 6) {
              ForEach(suggestions, id: \.self) { value in
                FilterChip(title: value, selected: draft.label == value, t: studio.t) {
                  draft.label = value
                }
              }
            }
          }.scrollIndicators(.never)
        }
      }
      Text(
        draft.kind == .reference
          ? "Creates a source link and backlink. It does not establish a world fact."
          : "Saved as draft relationships. Canon changes still require your review."
      )
      .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
    } footer: {
      Text("⇧⌘K").font(.studio(.caption)).foregroundStyle(studio.t.muted)
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Connect") { studio.saveRecordLink(draft) }
        .buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(!valid)
    }.onAppear {
      suggestions = Array(
        Set((try? studio.store.relations(worldID: draft.worldID))?.map(\.label) ?? [])
      ).sorted().prefix(6).map { $0 }
    }
  }
}

private struct RecordLinkChoice: View {
  let title: String
  let records: [LoreRecord]
  @Binding var selection: String
  let t: Theme
  @State private var showing = false
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.studio(.captionStrong)).foregroundStyle(t.secondary)
      Button {
        showing = true
      } label: {
        HStack(spacing: 8) {
          Text(records.first { $0.id == selection }?.title ?? "Choose a record…")
            .font(.studio(.control)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
          StudioIcon("chevron.down", size: 11).foregroundStyle(t.muted)
        }.padding(.horizontal, 10).frame(height: 34).contentShape(Rectangle())
      }.buttonStyle(.plain).background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
        .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.border, lineWidth: 1))
        .accessibilityLabel("\(title) record")
        .popover(isPresented: $showing) {
          SearchableRecordPicker(records: records, t: t) {
            selection = $0.id
            showing = false
          }
        }
    }.frame(maxWidth: .infinity)
  }
}
