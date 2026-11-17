import SwiftUI
import SynthesisCore

/// Shared by links, event sources and map markers. No arbitrary 60/80-record cutoff.
enum RecordChoices {
  static func matching(_ records: [LoreRecord], query: String) -> [LoreRecord] {
    let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !term.isEmpty else { return records }
    return records.filter {
      ([$0.title, $0.category] + ($0.aliases ?? [])).contains {
        $0.localizedStandardContains(term)
      }
    }
  }
}

struct SearchableRecordPicker: View {
  let records: [LoreRecord]
  let t: Theme
  var choose: (LoreRecord) -> Void
  @State private var query = ""
  var body: some View {
    let matches = RecordChoices.matching(records, query: query)
    VStack(alignment: .leading, spacing: 10) {
      SearchField(text: $query, placeholder: "Search names, aliases or categories", t: t)
      ScrollView {
        LazyVStack(spacing: 2) {
          ForEach(matches) { record in
            Button {
              choose(record)
            } label: {
              HStack(spacing: 10) {
                CategoryTile(record: record, t: t, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                  Text(record.title).font(.studio(.control)).lineLimit(1)
                  Text(
                    record.category.isEmpty
                      ? Vocabulary.kindLabel(record.kind)
                      : Vocabulary.displayCategory(record.category)
                  )
                  .font(.studio(.caption)).foregroundStyle(t.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
              }.padding(8).contentShape(Rectangle()).hoverFill(t)
            }.buttonStyle(.plain)
          }
          if matches.isEmpty {
            Text(records.isEmpty ? "No available records." : "No matching records.")
              .font(.studio(size: 13)).foregroundStyle(t.secondary).padding(.vertical, 24)
          }
        }
      }.frame(height: 250)
      Text("\(matches.count) records").font(.studio(size: 11)).foregroundStyle(t.secondary)
    }.padding(14).frame(width: 330).background(t.background).foregroundStyle(t.text)
  }
}
