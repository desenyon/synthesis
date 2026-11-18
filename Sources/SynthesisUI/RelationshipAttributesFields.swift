import SwiftUI
import SynthesisCore

struct RelationshipAttributesFields: View {
  @Binding var attributes: RelationshipAttributes
  let records: [LoreRecord]
  let t: Theme
  let editable: Bool
  @State private var expanded: Bool
  @State private var choosingEvidence = false

  init(
    attributes: Binding<RelationshipAttributes>, records: [LoreRecord], t: Theme,
    editable: Bool = true
  ) {
    _attributes = attributes
    self.records = records
    self.t = t
    self.editable = editable
    var details = attributes.wrappedValue
    details.kind = .unknown
    _expanded = State(initialValue: details != .init())
  }

  private var candidates: [LoreRecord] {
    let included = Set(attributes.evidenceRecordIDs)
    return records.filter { !included.contains($0.id) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Space.md) {
      ChoiceField(
        title: "Meaning", selection: $attributes.kind,
        choices: RelationshipAttributes.Kind.allCases.map { ($0, $0.title) }, t: t
      )
      .disabled(!editable)
      DisclosureGroup(isExpanded: $expanded) {
        ScrollView {
          VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .top, spacing: Space.md) {
              FormField(label: "Start", placeholder: "Unknown", text: $attributes.startLabel, t: t)
                .accessibilityLabel("Relationship start")
              FormField(label: "End", placeholder: "Unknown", text: $attributes.endLabel, t: t)
                .accessibilityLabel("Relationship end")
            }.disabled(!editable)
            if !relationshipDatesFit(attributes) {
              Text("Use up to \(RelationshipAttributes.dateLabelLimit) characters for each date.")
                .font(.studio(.caption)).foregroundStyle(t.warning)
            }
            HStack(alignment: .top, spacing: Space.md) {
              ChoiceField(
                title: "Strength", selection: $attributes.strength,
                choices: RelationshipAttributes.Strength.allCases.map { ($0, $0.title) }, t: t)
              ChoiceField(
                title: "Secrecy", selection: $attributes.secrecy,
                choices: RelationshipAttributes.Secrecy.allCases.map { ($0, $0.title) }, t: t
              )
              .help("Who knows about the relationship in the world")
            }.disabled(!editable)
            HStack(alignment: .top, spacing: Space.md) {
              ChoiceField(
                title: "Mutuality", selection: $attributes.mutuality,
                choices: RelationshipAttributes.Mutuality.allCases.map { ($0, $0.title) }, t: t)
              ChoiceField(
                title: "Status", selection: $attributes.status,
                choices: RelationshipAttributes.Status.allCases.map { ($0, $0.title) }, t: t)
            }.disabled(!editable)
            evidence
          }.padding(.top, Space.sm).padding(.trailing, Space.xs)
        }.frame(maxHeight: 235)
      } label: {
        Text("Dates, status and evidence").font(.studio(.control))
      }.tint(t.accent)
    }
  }

  private var evidence: some View {
    VStack(alignment: .leading, spacing: Space.xs) {
      HStack {
        Text("Evidence").font(.studio(.captionStrong)).foregroundStyle(t.secondary)
        Spacer()
        if editable {
          Button("Add source…") { choosingEvidence = true }.buttonStyle(QuietButton(t: t))
            .disabled(
              candidates.isEmpty
                || attributes.evidenceRecordIDs.count >= RelationshipAttributes.evidenceLimit
            )
            .help("Attach up to \(RelationshipAttributes.evidenceLimit) records from this world")
            .popover(isPresented: $choosingEvidence) {
              SearchableRecordPicker(records: candidates, t: t) { record in
                attributes.evidenceRecordIDs.append(record.id)
                choosingEvidence = false
              }
            }
        }
      }
      ForEach(attributes.evidenceRecordIDs, id: \.self) { id in
        let title = records.first(where: { $0.id == id })?.title ?? "Archived or unavailable source"
        HStack(spacing: Space.sm) {
          StudioLabel(title, icon: "doc.text").lineLimit(1)
          Spacer(minLength: Space.sm)
          if editable {
            IconButton(icon: "xmark", label: "Remove evidence: \(title)", t: t, size: 24) {
              attributes.evidenceRecordIDs.removeAll { $0 == id }
            }
          }
        }
      }
    }
  }
}
