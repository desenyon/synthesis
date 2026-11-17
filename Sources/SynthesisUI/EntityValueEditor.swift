import AppKit
import SwiftUI
import SynthesisCore
import UniformTypeIdentifiers

/// Shared typed controls for entity overrides, type defaults and template values.
struct EntityValueDraft {
  var primary = ""
  var secondary = ""
  var unit = ""
  var flag = false
  var selected: [String] = []
  var image: EntityValue?
  init(_ value: EntityValue?) {
    guard let value else { return }
    switch value {
    case .text(let text), .date(let text), .selection(let text), .entity(let text): primary = text
    case .selections(let values), .entities(let values): selected = values
    case .number(let value): primary = String(value)
    case .boolean(let value): flag = value
    case .range(let low, let high):
      primary = String(low)
      secondary = String(high)
    case .duration(let value, let label):
      primary = String(value)
      unit = label
    case .coordinates(let x, let y, let label):
      primary = String(x)
      secondary = String(y)
      unit = label
    case .media: image = value
    case .unknown: break
    }
  }
  func value(for field: EntityField) throws -> EntityValue {
    func number(_ text: String) throws -> Double {
      guard let number = Double(text.trimmingCharacters(in: .whitespaces)), number.isFinite else {
        throw SynthesisError.invalid("Enter a finite number using a decimal point.")
      }
      return number
    }
    switch field.kind {
    case .text: return .text(primary)
    case .date: return primary.isEmpty ? .unknown : .date(primary)
    case .number: return try .number(number(primary))
    case .boolean: return .boolean(flag)
    case .range: return try .range(number(primary), number(secondary))
    case .duration: return try .duration(number(primary), unit)
    case .coordinates: return try .coordinates(number(primary), number(secondary), unit)
    case .selection: return primary.isEmpty ? .unknown : .selection(primary)
    case .entity: return primary.isEmpty ? .unknown : .entity(primary)
    case .selections: return .selections(selected)
    case .entities: return .entities(selected)
    case .media: return image ?? .unknown
    case .formula: return .unknown
    }
  }
}

struct EntityValueInputs: View {
  let field: EntityField
  @Binding var draft: EntityValueDraft
  let records: [LoreRecord]
  let t: Theme
  @State private var imageError: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      switch field.kind {
      case .text:
        TextEditor(text: $draft.primary).font(.studio(size: 14)).scrollContentBackground(.hidden)
          .padding(8).frame(minHeight: 90, maxHeight: 150)
          .background(t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          .overlay(RoundedRectangle(cornerRadius: Metric.radius).stroke(t.border, lineWidth: 1))
          .accessibilityLabel(field.label)
      case .boolean:
        Toggle(field.label, isOn: $draft.flag).toggleStyle(.switch).tint(t.accent)
      case .selection:
        PlainMenu {
          ForEach(field.options, id: \.self) { option in Button(option) { draft.primary = option } }
        } label: {
          StudioLabel(
            draft.primary.isEmpty ? "Choose a value" : draft.primary, icon: "chevron.down")
        }
      case .selections, .entities:
        ScrollView {
          VStack(alignment: .leading, spacing: 10) {
            if field.kind == .selections {
              ForEach(field.options, id: \.self) { option in selection(option, label: option) }
            } else {
              ForEach(records.filter { $0.kind == "entity" }) { record in
                selection(record.id, label: record.title)
              }
              ForEach(draft.selected.filter { id in !records.contains { $0.id == id } }, id: \.self)
              { id in
                selection(id, label: "Archived entity · " + String(id.prefix(8)))
              }
            }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(4)
        }.frame(maxHeight: 220)
        Text("\(draft.selected.count) selected · select none for an explicit empty list")
          .font(.studio(.caption)).foregroundStyle(t.secondary)
      case .entity:
        PlainMenu(flexible: true) {
          ForEach(records.filter { $0.kind == "entity" }) { record in
            Button(record.title) { draft.primary = record.id }
          }
        } label: {
          StudioLabel(
            records.first { $0.id == draft.primary }?.title
              ?? (draft.primary.isEmpty ? "Choose an entity" : "Archived entity"), icon: "link"
          ).lineLimit(1)
        }
        if records.filter({ $0.kind == "entity" }).isEmpty {
          Text("Create an entity in this universe first.").font(.studio(.caption)).foregroundStyle(
            t.secondary)
        }
      case .range, .coordinates:
        HStack(spacing: 12) {
          FormField(
            label: field.kind == .range ? "Minimum" : "X", placeholder: "0", text: $draft.primary,
            t: t)
          FormField(
            label: field.kind == .range ? "Maximum" : "Y", placeholder: "0", text: $draft.secondary,
            t: t)
        }
        if field.kind == .coordinates {
          FormField(
            label: "Coordinate system or units",
            placeholder: "Optional · grid squares, kilometres…", text: $draft.unit, t: t)
        }
      case .duration:
        HStack(spacing: 12) {
          FormField(label: "Amount", placeholder: "0", text: $draft.primary, t: t)
          FormField(label: "World unit", placeholder: "seasons, cycles…", text: $draft.unit, t: t)
        }
      case .media:
        if case .media(let name, _, let raw) = draft.image {
          if let data = Data(base64Encoded: raw), let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 160)
              .clipShape(RoundedRectangle(cornerRadius: Metric.radius)).accessibilityLabel(name)
          }
          Text(name).font(.studio(.caption)).foregroundStyle(t.secondary).lineLimit(1)
        }
        Button("Choose image…") {
          let panel = NSOpenPanel()
          panel.allowedContentTypes = [.png, .jpeg]
          panel.canChooseDirectories = false
          panel.allowsMultipleSelection = false
          panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
              guard size <= 6_000_000 else {
                throw SynthesisError.invalid("Choose an image up to 6 MB.")
              }
              let data = try Data(contentsOf: url)
              draft.image = .media(
                name: url.lastPathComponent,
                mime: url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg",
                base64: data.base64EncodedString())
              imageError = nil
            } catch { imageError = error.localizedDescription }
          }
        }.buttonStyle(QuietButton(t: t))
        Text("PNG or JPEG · up to 6 MB · saved inside the world file").font(.studio(.caption))
          .foregroundStyle(t.secondary)
      case .formula:
        Text(field.formula).font(.studio(.body)).textSelection(.enabled)
      case .number:
        FormField(placeholder: "Number", text: $draft.primary, t: t)
      case .date:
        FormField(
          placeholder: "Year 60, early spring · or an uncertain date", text: $draft.primary, t: t)
        Text("Use your world's calendar. Dates are preserved exactly as written.").font(
          .studio(.caption)
        ).foregroundStyle(t.secondary)
      }
      if let imageError { Text(imageError).font(.studio(.caption)).foregroundStyle(t.danger) }
    }
  }
  private func selection(_ id: String, label: String) -> some View {
    Toggle(
      label,
      isOn: Binding(
        get: { draft.selected.contains(id) },
        set: { selected in
          if selected {
            if !draft.selected.contains(id) { draft.selected.append(id) }
          } else {
            draft.selected.removeAll { $0 == id }
          }
        })
    ).toggleStyle(.checkbox).font(.studio(size: 14))
  }

}

struct EntityValueSheet: View {
  @ObservedObject var studio: Studio
  @State private var scope: EntitySchemaScope
  let field: EntityField
  let inherited: Bool
  let save: (EntityValue?) throws -> Void
  let close: () -> Void
  @State private var draft: EntityValueDraft
  @State private var failure: String?
  init(
    studio: Studio, field: EntityField, value: EntityValue?, inherited: Bool = false,
    worldID: String? = nil,
    save: @escaping (EntityValue?) throws -> Void, close: @escaping () -> Void
  ) {
    self.studio = studio
    self.field = field
    self.inherited = inherited
    _scope = State(initialValue: EntitySchemaScope(worldID: worldID ?? studio.worldID))
    self.save = save
    self.close = close
    _draft = State(initialValue: EntityValueDraft(value))
  }
  var body: some View {
    SheetScaffold(
      title: field.label, subtitle: field.note.isEmpty ? field.kind.label : field.note,
      t: studio.t, width: 490, close: close
    ) {
      EntityValueInputs(
        field: field, draft: $draft,
        records: (try? studio.store.records(worldID: scope.worldID)) ?? [], t: studio.t)
      if let message = scope.mismatchMessage(activeWorldID: studio.worldID) {
        Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
      }
      if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
    } footer: {
      Button(inherited ? "Use inherited value" : "Remove override") { apply(nil) }
        .buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Unknown") { apply(.unknown) }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Save") {
        do { apply(try draft.value(for: field)) } catch { failure = error.localizedDescription }
      }
      .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
    }
  }
  private func apply(_ value: EntityValue?) {
    do {
      try scope.requireCurrentWorld(studio.worldID)
      try save(value)
      close()
    } catch { failure = error.localizedDescription }
  }
}
