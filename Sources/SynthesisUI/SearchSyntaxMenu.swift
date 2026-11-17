import SwiftUI

/// Shared query examples write only the search field; they never create lore or call a model.
struct SearchSyntaxMenu: View {
  @Binding var query: String
  let t: Theme
  var body: some View {
    PlainMenu {
      Text("Search filters").font(.studio(.control)).padding(6)
      Text("Combine filters with words. Use double quotes around names with spaces.")
        .font(.studio(.caption)).foregroundStyle(t.secondary).padding(6)
      ForEach(Self.examples, id: \.query) { example in
        Button {
          query = example.query
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(example.query).font(.studio(.caption))
            Text(example.detail).font(.studio(.caption)).foregroundStyle(t.muted)
          }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3)
        }
      }
      Text(
        "Filters intersect. Times refer to saved edits, not fictional dates. Up to 50 records per search."
      )
      .font(.studio(.caption)).foregroundStyle(t.secondary).padding(6)
    } label: {
      StudioIcon("questionmark.circle", size: 13).foregroundStyle(t.secondary)
        .frame(width: 26, height: 26).hoverFill(t, radius: Metric.smallRadius)
    }.help("Search syntax and examples").accessibilityLabel("Search syntax and examples")
  }
  static let examples: [(query: String, detail: String)] = [
    ("type:character", "Find a category or type:document / entity / idea"),
    ("type:character faction:Tidekeepers", "Actual links to a system or faction"),
    ("status:canon updated:7d", "Canon records saved in the last seven days"),
    ("tag:\"story arc\"", "Exact tag; alias: also finds alternate names"),
    ("related:\"Mira Vale\"", "Actual relationships in either direction"),
    ("created:7d", "Records created in the last seven days"),
  ]
}
