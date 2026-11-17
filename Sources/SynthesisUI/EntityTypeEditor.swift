import SwiftUI
import SynthesisCore

struct EntityTypesSheet: View {
  @ObservedObject var studio: Studio
  @State private var scope: EntitySchemaScope
  let close: () -> Void
  @State private var types: [EntityType] = []
  @State private var templates: [EntityTemplate] = []
  @State private var editType: EntityType?
  @State private var creatingType = false
  @State private var typeEditor = false
  @State private var editTemplate: EntityTemplate?
  @State private var templateEditor = false
  @State private var templateTypeID = ""
  @State private var showArchived = false
  @State private var failure: String?
  init(studio: Studio, worldID: String? = nil, close: @escaping () -> Void) {
    self.studio = studio
    self.close = close
    _scope = State(initialValue: EntitySchemaScope(worldID: worldID ?? studio.worldID))
  }
  var body: some View {
    SheetScaffold(
      title: "Entity types & templates",
      subtitle: "Define the details your universe needs. Existing writing stays intact.",
      t: studio.t, width: 650, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("Types").font(.studio(.control))
            Spacer()
            Button("New type") {
              editType = nil
              creatingType = true
              typeEditor = true
            }
            .buttonStyle(QuietButton(t: studio.t))
          }
          if types.filter({ showArchived || !$0.archived }).isEmpty {
            Text(
              "Create a type for species, artifacts, kingdoms — or anything your world calls for."
            )
            .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
          }
          ForEach(types.filter { showArchived || !$0.archived }) { type in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(type.name).font(.studio(size: 14, weight: .medium)).lineLimit(1)
                Text(
                  type.archived
                    ? "Archived · existing profiles retained"
                    : type.parentTypeID.flatMap { id in types.first { $0.id == id }?.name }.map {
                      "Inherits from \($0)"
                    } ?? "\(type.fields.count) fields"
                )
                .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(1)
              }
              Spacer()
              Button("Edit") {
                editType = type
                creatingType = false
                typeEditor = true
              }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost))
              Button(type.archived ? "Restore" : "Archive") {
                apply {
                  let worldID = scope.worldID
                  try studio.store.setEntityTypeArchived(
                    worldID: worldID, id: type.id, archived: !type.archived,
                    expectedVersion: type.version)
                  if !type.archived {
                    studio.show("Archived entity type", icon: "archivebox", actionTitle: "Undo") {
                      studio.perform {
                        try studio.store.setEntityTypeArchived(
                          worldID: worldID, id: type.id, archived: false,
                          expectedVersion: type.version + 1)
                        try studio.reload()
                      }
                    }
                  }
                }
              }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
            }.padding(12).background(
              studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          }
          HStack {
            Text("Templates").font(.studio(.control))
            Spacer()
            PlainMenu {
              ForEach(types.filter { !$0.archived }) { type in
                Button(type.name) {
                  templateTypeID = type.id
                  editTemplate = nil
                  templateEditor = true
                }
              }
            } label: {
              StudioLabel("New template", icon: "plus")
            }
            .disabled(types.filter { !$0.archived }.isEmpty)
          }
          if templates.filter({ showArchived || !$0.archived }).isEmpty {
            Text("Save a reusable starting profile here or from an entity's Properties tab.")
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
          }
          ForEach(templates.filter { showArchived || !$0.archived }) { item in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.studio(size: 14, weight: .medium)).lineLimit(1)
                Text(types.first { $0.id == item.typeID }?.name ?? "Entity type")
                  .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              }
              Spacer()
              Button("Edit") {
                editTemplate = item
                templateTypeID = item.typeID
                templateEditor = true
              }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost))
              Button(item.archived ? "Restore" : "Archive") {
                apply {
                  let worldID = scope.worldID
                  try studio.store.setEntityTemplateArchived(
                    worldID: worldID, id: item.id, archived: !item.archived,
                    expectedVersion: item.version)
                  if !item.archived {
                    studio.show("Archived entity template", icon: "archivebox", actionTitle: "Undo")
                    {
                      studio.perform {
                        try studio.store.setEntityTemplateArchived(
                          worldID: worldID, id: item.id, archived: false,
                          expectedVersion: item.version + 1)
                        try studio.reload()
                      }
                    }
                  }
                }
              }.buttonStyle(QuietButton(t: studio.t, role: .ghost))
            }.padding(12).background(
              studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          }
          Toggle("Show archived types and templates", isOn: $showArchived).toggleStyle(.checkbox)
            .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          if let message = scope.mismatchMessage(activeWorldID: studio.worldID) {
            Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
          }
          if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
        }
      }.frame(maxHeight: 470)
    } footer: {
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t))
    }
    .onAppear {
      load()
      if studio.captureHint.contains("entity-types-edit") {
        editType = types.first
        typeEditor = true
      }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
    .studioSheet(isPresented: $typeEditor) {
      EntityTypeEditor(
        studio: studio, type: creatingType ? nil : editType, worldID: scope.worldID,
        close: { typeEditor = false })
    }
    .studioSheet(isPresented: $templateEditor) {
      EntityTemplateEditor(
        studio: studio, typeID: templateTypeID, existing: editTemplate, worldID: scope.worldID,
        close: { templateEditor = false })
    }
  }
  private func load() {
    do {
      try scope.requireCurrentWorld(studio.worldID)
      types = try studio.store.entityTypes(worldID: scope.worldID, includingArchived: true)
      templates = try studio.store.entityTemplates(worldID: scope.worldID, includingArchived: true)
    } catch { failure = error.localizedDescription }
  }
  private func apply(_ work: () throws -> Void) {
    do {
      try scope.requireCurrentWorld(studio.worldID)
      try work()
      try studio.reload()
      failure = nil
    } catch { failure = error.localizedDescription }
  }
}

struct EntityTypeEditor: View {
  @ObservedObject var studio: Studio
  @State private var scope: EntitySchemaScope
  let type: EntityType?
  let close: () -> Void
  @State private var name: String
  @State private var description: String
  @State private var parentID: String?
  @State private var parentSchema: EntityResolvedType?
  @State private var fields: [EntityField]
  @State private var defaults: [String: EntityValue]
  @State private var fieldEditor = false
  @State private var editingField: EntityField?
  @State private var defaultField: EntityField?
  @State private var failure: String?
  init(studio: Studio, type: EntityType?, worldID: String? = nil, close: @escaping () -> Void) {
    self.studio = studio
    self.type = type
    self.close = close
    _scope = State(
      initialValue: EntitySchemaScope(worldID: type?.worldID ?? worldID ?? studio.worldID))
    _name = State(initialValue: type?.name ?? "")
    _description = State(initialValue: type?.description ?? "")
    _parentID = State(initialValue: type?.parentTypeID)
    _parentSchema = State(
      initialValue: type?.parentTypeID.flatMap {
        try? studio.store.resolvedEntityType(
          worldID: type?.worldID ?? worldID ?? studio.worldID, id: $0)
      })
    _fields = State(initialValue: type?.fields ?? [])
    _defaults = State(initialValue: type?.defaults ?? [:])
  }
  private var types: [EntityType] {
    guard scope.worldID == studio.worldID else { return [] }
    return (try? studio.store.entityTypes(worldID: scope.worldID)) ?? []
  }
  private var inherited: EntityResolvedType? { parentSchema }
  private var allFields: [EntityField] {
    var result = inherited?.fields ?? []
    for field in fields {
      if let index = result.firstIndex(where: { $0.key == field.key }) {
        result[index] = field
      } else {
        result.append(field)
      }
    }
    return result
  }
  var body: some View {
    SheetScaffold(
      title: type == nil ? "New entity type" : "Edit entity type",
      subtitle: "Changes remain drafts in each profile. Accepted property canon stays frozen.",
      t: studio.t, width: 650, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          FormField(
            label: "Name", placeholder: "Species, settlement, artifact…", text: $name, t: studio.t)
          FormField(
            label: "Description", placeholder: "What this type represents", text: $description,
            t: studio.t)
          HStack {
            Text("Inherits from").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
            Spacer()
            PlainMenu {
              Button("No parent") { parentID = nil }
              ForEach(types.filter { $0.id != type?.id }) { item in
                Button(item.name) { parentID = item.id }
              }
            } label: {
              StudioLabel(
                types.first { $0.id == parentID }?.name ?? "No parent", icon: "chevron.down"
              ).lineLimit(1)
            }
          }
          if let type {
            PlainMenu {
              ForEach(
                (try? studio.store.entityTypeHistory(worldID: scope.worldID, typeID: type.id))
                  ?? [], id: \.version
              ) { revision in
                Button("Load revision \(revision.version) as draft") {
                  name = revision.name
                  description = revision.description
                  parentID = revision.parentTypeID
                  fields = revision.fields
                  defaults = revision.defaults
                }
              }
            } label: {
              StudioLabel("Previous versions", icon: "clock")
            }
          }
          HStack {
            Text("Fields · \(allFields.count)").font(.studio(.control))
            Spacer()
            Button("Add field") {
              editingField = nil
              fieldEditor = true
            }.buttonStyle(QuietButton(t: studio.t))
          }
          ForEach(allFields) { field in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(field.label).font(.studio(size: 14, weight: .medium))
                  Text(
                    "\(field.kind.label) · \(field.key)"
                      + (fields.contains { $0.key == field.key } ? "" : " · inherited")
                  )
                  .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
                }
                Spacer()
                Button(fields.contains { $0.key == field.key } ? "Edit" : "Override") {
                  editingField = field
                  fieldEditor = true
                }
                .buttonStyle(QuietButton(t: studio.t, role: .ghost))
                if field.kind != .formula {
                  Button("Default") { defaultField = field }.buttonStyle(
                    QuietButton(t: studio.t, role: .ghost))
                }
                if fields.contains(where: { $0.key == field.key }) {
                  IconButton(
                    icon: "minus", label: "Remove \(field.label) from this type", t: studio.t,
                    size: 26
                  ) {
                    fields.removeAll { $0.key == field.key }
                    defaults.removeValue(forKey: field.key)
                  }
                }
              }
              if let value = defaults[field.key] ?? inherited?.defaults[field.key] {
                Text("Default: \(value.summary)").font(.studio(.caption)).foregroundStyle(
                  studio.t.secondary
                ).lineLimit(2)
              }
              if let condition = field.condition {
                Text("Shown when \(condition.field) = \(condition.equals.summary)").font(
                  .studio(.caption)
                ).foregroundStyle(studio.t.secondary)
              }
            }.padding(12).background(
              studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          }
          Text(
            "Removing or changing a field is blocked if it would invalidate saved values. Inherited fields can be overridden without changing the parent type."
          )
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          if let message = scope.mismatchMessage(activeWorldID: studio.worldID) {
            Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
          }
          if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
        }
      }.frame(maxHeight: 475)
    } footer: {
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Save type") {
        do {
          try scope.requireCurrentWorld(studio.worldID)
          _ = try studio.store.saveEntityType(
            worldID: scope.worldID, id: type?.id, expectedVersion: type?.version, name: name,
            description: description, parentTypeID: parentID, fields: fields, defaults: defaults)
          try studio.reload()
          close()
        } catch { failure = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
    }
    .onChange(of: parentID) { _, id in
      parentSchema = id.flatMap {
        try? studio.store.resolvedEntityType(worldID: scope.worldID, id: $0)
      }
    }
    .studioSheet(isPresented: $fieldEditor) {
      EntityFieldEditor(
        studio: studio, field: editingField, peers: allFields, worldID: scope.worldID
      ) { field in
        if let index = fields.firstIndex(where: { $0.key == field.key }) {
          fields[index] = field
        } else {
          fields.append(field)
        }
        fieldEditor = false
      } close: {
        fieldEditor = false
      }
    }
    .studioSheet(item: $defaultField) { field in
      EntityValueSheet(
        studio: studio, field: field, value: defaults[field.key] ?? inherited?.defaults[field.key],
        inherited: inherited?.defaults[field.key] != nil, worldID: scope.worldID
      ) { value in
        defaults[field.key] = value
      } close: {
        defaultField = nil
      }
    }
  }
}

struct EntityFieldEditor: View {
  @ObservedObject var studio: Studio
  @State private var scope: EntitySchemaScope
  let field: EntityField?
  let peers: [EntityField]
  let save: (EntityField) -> Void
  let close: () -> Void
  @State private var key: String
  @State private var label: String
  @State private var kind: EntityFieldKind
  @State private var note: String
  @State private var options: String
  @State private var formula: String
  @State private var conditionKey: String?
  @State private var conditionDraft: EntityValueDraft
  @State private var failure: String?
  init(
    studio: Studio, field: EntityField?, peers: [EntityField], worldID: String? = nil,
    save: @escaping (EntityField) -> Void, close: @escaping () -> Void
  ) {
    self.studio = studio
    self.field = field
    self.peers = peers
    _scope = State(initialValue: EntitySchemaScope(worldID: worldID ?? studio.worldID))
    self.save = save
    self.close = close
    _key = State(initialValue: field?.key ?? "")
    _label = State(initialValue: field?.label ?? "")
    _kind = State(initialValue: field?.kind ?? .text)
    _note = State(initialValue: field?.note ?? "")
    _options = State(initialValue: field?.options.joined(separator: ", ") ?? "")
    _formula = State(initialValue: field?.formula ?? "")
    _conditionKey = State(initialValue: field?.condition?.field)
    _conditionDraft = State(initialValue: EntityValueDraft(field?.condition?.equals))
  }
  var body: some View {
    SheetScaffold(
      title: field == nil ? "Add field" : "Edit field", t: studio.t, width: 550, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          FormField(
            label: "Label", placeholder: "Birthplace, strength, allegiance…", text: $label,
            t: studio.t)
          FormField(
            label: "Stable key", placeholder: "lowercase_with_underscores", text: $key, t: studio.t
          ).disabled(field != nil)
          PlainMenu {
            ForEach(EntityFieldKind.allCases, id: \.self) { kind in
              Button(kind.label) { self.kind = kind }
            }
          } label: {
            StudioLabel(kind.label, icon: "chevron.down")
          }
          FormField(
            label: "Help text", placeholder: "Optional guidance for this field", text: $note,
            t: studio.t)
          if [.selection, .selections].contains(kind) {
            FormField(
              label: "Choices, separated by commas", placeholder: "Living, Deceased, Unknown",
              text: $options, t: studio.t)
          }
          if kind == .formula {
            FormField(
              label: "Formula", placeholder: "strength * 2 + max(agility, 3)", text: $formula,
              t: studio.t)
            Text(
              "Use numeric field keys, + − * / %, parentheses, min, max, abs, round, floor or ceil. Missing inputs stay unknown."
            )
            .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
          }
          HStack {
            Text("Visibility").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
            Spacer()
            PlainMenu {
              Button("Always visible") { conditionKey = nil }
              ForEach(
                peers.filter {
                  $0.key != key && [.text, .number, .boolean, .date, .selection].contains($0.kind)
                }
              ) { peer in
                Button("When \(peer.label) equals…") {
                  conditionKey = peer.key
                  conditionDraft = EntityValueDraft(nil)
                }
              }
            } label: {
              StudioLabel(
                conditionKey == nil ? "Always visible" : "Conditional", icon: "chevron.down")
            }
          }
          if let peer = peers.first(where: { $0.key == conditionKey }) {
            Text("Show when \(peer.label) equals:").font(.studio(.captionStrong))
            EntityValueInputs(
              field: peer, draft: $conditionDraft,
              records: (try? studio.store.records(worldID: scope.worldID)) ?? [], t: studio.t)
          }
          if let message = scope.mismatchMessage(activeWorldID: studio.worldID) {
            Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
          }
          if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
        }
      }.frame(maxHeight: 470)
    } footer: {
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Keep field") {
        do {
          try scope.requireCurrentWorld(studio.worldID)
          var condition: EntityFieldCondition?
          if let peer = peers.first(where: { $0.key == conditionKey }) {
            condition = EntityFieldCondition(
              field: peer.key, equals: try conditionDraft.value(for: peer))
          }
          guard !label.trimmingCharacters(in: .whitespaces).isEmpty,
            key.range(of: "^[a-z][a-z0-9_]{0,47}$", options: .regularExpression) != nil,
            field != nil || !peers.contains(where: { $0.key == key })
          else {
            throw SynthesisError.invalid("Use a label and a unique lowercase key.")
          }
          save(
            EntityField(
              key: key, label: label, kind: kind, note: note,
              options: options.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
              }, formula: formula, condition: condition))
        } catch { failure = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
    }
    .onChange(of: label) { old, new in
      if field == nil && (key.isEmpty || key == slug(old)) { key = slug(new) }
    }
  }
  private func slug(_ text: String) -> String {
    String(
      text.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" }.prefix(48))
  }
}

struct EntityTemplateEditor: View {
  @ObservedObject var studio: Studio
  @State private var scope: EntitySchemaScope
  let typeID: String
  let existing: EntityTemplate?
  let close: () -> Void
  @State private var name: String
  @State private var description: String
  @State private var text: String
  @State private var values: [String: EntityValue]
  @State private var resolved: EntityResolvedType?
  @State private var editing: EntityField?
  @State private var failure: String?
  init(
    studio: Studio, typeID: String, existing: EntityTemplate? = nil, source: LoreRecord? = nil,
    values: [String: EntityValue] = [:], worldID: String? = nil, close: @escaping () -> Void
  ) {
    self.studio = studio
    self.typeID = typeID
    self.existing = existing
    self.close = close
    _scope = State(
      initialValue: EntitySchemaScope(
        worldID: existing?.worldID ?? source?.worldID ?? worldID ?? studio.worldID))
    _name = State(initialValue: existing?.name ?? "")
    _description = State(initialValue: existing?.description ?? "")
    _text = State(initialValue: existing?.body ?? source?.body ?? "")
    _values = State(initialValue: existing?.values ?? values)
  }
  var body: some View {
    SheetScaffold(
      title: existing == nil ? "Save entity template" : "Edit template",
      subtitle: "New entities receive independent draft copies. No canon is copied or approved.",
      t: studio.t, width: 610, close: close
    ) {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          if let existing {
            PlainMenu {
              ForEach(
                (try? studio.store.entityTemplateHistory(
                  worldID: scope.worldID, templateID: existing.id)) ?? [], id: \.version
              ) { revision in
                Button("Load revision \(revision.version) as draft") {
                  name = revision.name
                  description = revision.description
                  text = revision.body
                  values = revision.values
                }
              }
            } label: {
              StudioLabel("Previous versions", icon: "clock")
            }
          }
          FormField(
            label: "Template name", placeholder: "Coastal settlement, wandering scholar…",
            text: $name, t: studio.t)
          FormField(
            label: "Description", placeholder: "When to use this template", text: $description,
            t: studio.t)
          Text("Starting text").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
          TextEditor(text: $text).font(.studio(size: 14)).scrollContentBackground(.hidden).padding(
            8
          )
          .frame(height: 140).background(
            studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius)
          )
          .accessibilityLabel("Template starting text")
          if let resolved {
            Text("Properties · \(resolved.type.name)").font(.studio(.captionStrong))
              .foregroundStyle(studio.t.secondary)
            ForEach(resolved.fields.filter { $0.kind != .formula }) { field in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(field.label).font(.studio(size: 14))
                  Text((values[field.key] ?? resolved.defaults[field.key] ?? .unknown).summary)
                    .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(2)
                }
                Spacer()
                Button("Edit") { editing = field }.buttonStyle(
                  QuietButton(t: studio.t, role: .ghost))
              }.padding(.vertical, 4)
            }
          }
          if let message = scope.mismatchMessage(activeWorldID: studio.worldID) {
            Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
          }
          if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
        }
      }.frame(maxHeight: 430)
    } footer: {
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Save template") {
        do {
          try scope.requireCurrentWorld(studio.worldID)
          _ = try studio.store.saveEntityTemplate(
            worldID: scope.worldID, id: existing?.id, expectedVersion: existing?.version,
            typeID: typeID, name: name, description: description, body: text, values: values)
          try studio.reload()
          close()
        } catch { failure = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
    }
    .onAppear {
      do {
        try scope.requireCurrentWorld(studio.worldID)
        resolved = try studio.store.resolvedEntityType(worldID: scope.worldID, id: typeID)
      } catch { failure = error.localizedDescription }
    }
    .studioSheet(item: $editing) { field in
      EntityValueSheet(
        studio: studio, field: field, value: values[field.key] ?? resolved?.defaults[field.key],
        inherited: resolved?.defaults[field.key] != nil, worldID: scope.worldID
      ) { value in
        values[field.key] = value
      } close: {
        editing = nil
      }
    }
  }
}
