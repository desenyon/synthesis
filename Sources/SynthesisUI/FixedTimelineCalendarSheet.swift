import SwiftUI
import SynthesisCore

struct FixedTimelineCalendarSheet: View {
  @ObservedObject var studio: Studio
  let worldID: String
  var close: () -> Void

  @State private var name = ""
  @State private var months = ""
  @State private var week = ""
  @State private var hours = ""

  var body: some View {
    SheetScaffold(
      title: "Create Timeline calendar",
      subtitle:
        "Month lengths repeat every year. The first day of year 0 sets the axis origin.",
      t: studio.t, close: close
    ) {
      FormField(label: "Name", placeholder: "Calendar name", text: $name, t: studio.t)
      FormField(
        label: "Days in every month", placeholder: "Example: 30, 30, 28, 34", text: $months,
        t: studio.t)
      HStack(spacing: 10) {
        FormField(label: "Days per week", placeholder: "Example: 7", text: $week, t: studio.t)
        FormField(label: "Hours per day", placeholder: "Example: 24", text: $hours, t: studio.t)
      }
      Text("This calendar’s lengths are fixed once saved.")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create calendar", action: save)
        .buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction)
        .disabled(
          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || months.isEmpty || week.isEmpty || hours.isEmpty)
    }
  }

  private func save() {
    studio.perform {
      guard worldID == studio.worldID else { throw SynthesisError.stale }
      let values = months.split(separator: ",", omittingEmptySubsequences: false)
        .map { Int($0.trimmingCharacters(in: .whitespaces)) }
      guard !values.isEmpty, values.allSatisfy({ $0 != nil }),
        let week = Int(week.trimmingCharacters(in: .whitespaces)),
        let hours = Int(hours.trimmingCharacters(in: .whitespaces))
      else {
        throw SynthesisError.invalid(
          "Enter comma-separated whole numbers for month lengths and whole numbers for the week and day."
        )
      }
      try studio.store.createTimelineCalendar(
        worldID: worldID, name: name, monthLengths: values.compactMap { $0 },
        daysPerWeek: week, hoursPerDay: hours)
      close()
      try studio.reload()
    }
  }
}
