import SwiftUI
import SynthesisCore

struct WorkspaceHeading: View {
  let title: String
  let subtitle: String
  let t: Theme
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.system(size: 28, weight: .medium)).tracking(-0.8)
      Text(subtitle).font(.system(size: 13)).foregroundStyle(t.secondary)
    }
  }
}

struct TimelineScreen: View {
  @ObservedObject var studio: Studio
  @State private var events: [WorldEvent] = []
  @State private var adding = false
  @State private var title = ""
  @State private var date = ""
  @State private var order = ""
  @State private var source = ""
  @State private var filter = ""
  @State private var spacing = 30.0
  var filtered: [WorldEvent] {
    events.filter {
      filter.isEmpty || $0.dateLabel.localizedCaseInsensitiveContains(filter)
        || $0.title.localizedCaseInsensitiveContains(filter)
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      HStack {
        WorkspaceHeading(
          title: "Universal history",
          subtitle: "History with room for uncertainty, myth, and missing years.", t: studio.t)
        Spacer()
        Button {
          source = studio.records.first?.id ?? ""
          adding = true
        } label: {
          Image(systemName: "plus")
        }.buttonStyle(QuietButton(t: studio.t, primary: true)).disabled(studio.records.isEmpty)
          .help("Add event")
      }
      HStack {
        TextField("Find an era or event", text: $filter).textFieldStyle(.plain)
        Spacer()
        IconButton(icon: "minus", label: "Compact timeline", t: studio.t) {
          spacing = max(12, spacing - 12)
        }
        IconButton(icon: "plus", label: "Expand timeline", t: studio.t) {
          spacing = min(120, spacing + 12)
        }
      }.font(.system(size: 13))
      ScrollView {
        VStack(alignment: .leading, spacing: spacing) {
          ForEach(filtered) { event in
            HStack(alignment: .top, spacing: 20) {
              VStack(spacing: 8) {
                Circle().fill(studio.t.accent.opacity(0.7)).frame(width: 9, height: 9)
                Rectangle().fill(studio.t.border).frame(width: 1, height: 80)
              }.frame(width: 18)
              VStack(alignment: .leading, spacing: 12) {
                Text(event.dateLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(
                  studio.t.accent)
                Text(event.title).font(.system(size: 24, weight: .medium))
                if let record = studio.records.first(where: { $0.id == event.sourceID }) {
                  Button {
                    studio.openRecord(record)
                  } label: {
                    Label(record.title + " ↗", systemImage: "doc.text")
                  }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(studio.t.secondary)
                }
                Text("Draft event").font(.system(size: 10)).foregroundStyle(studio.t.muted)
              }
              Spacer()
            }.padding(.vertical, 10)
          }
          if filtered.isEmpty {
            Text(events.isEmpty ? "Every history starts somewhere." : "No matching events.").font(
              .system(size: 24, weight: .medium)
            ).padding(.top, 70)
            Text(
              studio.records.isEmpty
                ? "Create a source document or entity in Library first."
                : "Add an event with a source record. Dates can be unknown."
            ).font(.system(size: 14)).foregroundStyle(studio.t.secondary)
          }
        }.padding(.vertical, 24).frame(maxWidth: 800, alignment: .leading).frame(
          maxWidth: .infinity, alignment: .leading)
      }
    }.padding(30).onAppear { refresh() }
      .sheet(isPresented: $adding) {
        VStack(alignment: .leading, spacing: 20) {
          Text("A moment that matters.").font(.system(size: 24, weight: .medium))
          TextField("Event title", text: $title)
          TextField("Date or era · leave empty if unknown", text: $date)
          TextField("Optional chronology order (integer)", text: $order)
          Picker("Source", selection: $source) {
            ForEach(studio.records) { Text($0.title).tag($0.id) }
          }
          Text(
            "Date labels preserve your world's own language. Ordering does not invent calendar precision."
          ).font(.caption).foregroundStyle(.secondary)
          HStack {
            Button("Cancel") { adding = false }
            Spacer()
            Button("Add event") {
              studio.perform {
                guard order.isEmpty || Int(order) != nil else {
                  throw SynthesisError.invalid("Order must be an integer or blank.")
                }
                _ = try studio.store.addEvent(
                  worldID: studio.worldID, title: title, date: date, source: source,
                  order: Int(order))
                adding = false
                title = ""
                date = ""
                order = ""
                refresh()
              }
            }.disabled(title.isEmpty || source.isEmpty)
          }
        }.textFieldStyle(.roundedBorder).padding(28).frame(width: 430)
      }
  }
  private func refresh() {
    studio.perform { events = try studio.store.events(worldID: studio.worldID) }
  }
}
