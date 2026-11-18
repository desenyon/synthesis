import SwiftUI
import SynthesisCore

struct StudioSheet: View {
  @ObservedObject var studio: Studio
  let sheet: Studio.Sheet
  @State private var name = ""
  @State private var kind = "lore"
  @State private var category = ""
  @State private var worldName = ""
  @State private var entityTypeID: String?
  @State private var entityTemplateID: String?
  @State private var managingEntityTypes = false
  @State private var creationScope: EntitySchemaScope
  init(studio: Studio, sheet: Studio.Sheet) {
    self.studio = studio
    self.sheet = sheet
    _creationScope = State(initialValue: EntitySchemaScope(worldID: studio.worldID))
    _kind = State(initialValue: studio.newRecordKind)
    _category = State(initialValue: studio.libraryCategory ?? studio.worldDefaults.entityCategory)
    _worldName = State(initialValue: studio.world?.name ?? "")
    let target = studio.renameTarget ?? studio.conversationID
    _name = State(
      initialValue: sheet == .rename
        ? (studio.conversations.first { $0.id == target }?.title ?? "") : "")
  }
  private func close() { studio.sheet = nil }
  private var nameIsEmpty: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  var body: some View {
    Group {
      switch sheet {
      case .components:
        if let scope = studio.creativeScope {
          CreativeComponentsSheet(studio: studio, scope: scope, parentID: studio.creativeParent)
            .id(
              "\(studio.worldID):\(scope.rawValue):\(studio.creativeParent ?? ""):\(studio.captureNonce)"
            )
        }
      case .layouts: WorkspaceLayoutsSheet(studio: studio)
      case .navigation: SidebarCustomizationSheet(studio: studio)
      case .activity: WorldActivitySheet(studio: studio)
      case .relationshipHistory:
        if let target = studio.relationshipHistoryTarget {
          RelationshipHistorySheet(studio: studio, target: target, close: close)
        }
      case .linkRecords:
        if let draft = studio.recordLinkDraft { RecordLinkSheet(studio: studio, draft: draft) }
      case .splitRecord: SplitRecordPicker(studio: studio)
      case .project: NewProjectSheet(studio: studio)
      case .world: world
      case .document: document
      case .rename: rename
      case .onboarding: onboarding
      case .whatIf: WhatIfSheet(studio: studio)
      case .sendWhatIf: SendWhatIfSheet(studio: studio)
      }
    }
  }
  private func finishSetup() { studio.completeOnboarding() }
  private var onboarding: some View {
    SheetScaffold(
      title: "Welcome to Synthesis",
      subtitle: "Your universe, your way. You can change these choices in Settings.", t: studio.t,
      width: 560, close: finishSetup
    ) {
      FormField(label: "Your first world", placeholder: "World name", text: $worldName, t: studio.t)
      {
        // Return in the name field means "Start creating", like the default button.
        studio.renameWorld(worldName)
        if studio.error == nil { studio.completeOnboarding() }
      }
      HStack {
        Text("Start creating").font(.studio(.control))
        Spacer()
        ModeSwitch(studio: studio)
      }
      HStack {
        Text("Appearance").font(.studio(.control))
        Spacer()
        AppearanceSwitch(studio: studio)
      }
      if studio.mode == .assisted {
        VStack(alignment: .leading, spacing: 12) {
          SectionLabel(title: "Assistant", t: studio.t)
          AssistantConnection(studio: studio)
        }
      }
    } footer: {
      Spacer()
      Button("Start creating") {
        studio.renameWorld(worldName)
        if studio.error == nil { studio.completeOnboarding() }
      }.buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(worldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
  private var world: some View {
    SheetScaffold(
      title: "New world", subtitle: "A name is enough. Everything else can stay open.",
      t: studio.t, width: 400, close: close
    ) {
      FormField(placeholder: "World name", text: $name, t: studio.t) {
        if !nameIsEmpty { studio.createWorld(name) }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create world") { studio.createWorld(name) }
        .buttonStyle(QuietButton(t: studio.t, primary: true)).keyboardShortcut(.defaultAction)
        .disabled(nameIsEmpty)
    }
  }
  private var document: some View {
    let kinds: [(String, String, String, String)] = [
      ("lore", "Document", "doc.text", "Long-form writing"),
      ("entity", "Entity", "circle.hexagongrid", "A character, place, faction…"),
      ("capture", "Idea", "lightbulb", "A loose thought for later"),
    ]
    let types =
      creationScope.worldID == studio.worldID
      ? (try? studio.store.entityTypes(worldID: creationScope.worldID)) ?? [] : []
    let templates =
      creationScope.worldID == studio.worldID
      ? (try? studio.store.entityTemplates(worldID: creationScope.worldID)) ?? [] : []
    let create = {
      guard (try? creationScope.requireCurrentWorld(studio.worldID)) != nil else { return }
      if kind == "entity", let entityTypeID {
        guard studio.flushEditor() else { return }
        studio.perform {
          let record = try studio.store.createTypedEntity(
            worldID: creationScope.worldID, typeID: entityTypeID, title: name,
            templateID: entityTemplateID
          )
          try studio.reload()
          studio.openRecord(record)
          studio.recordTabs[record.id] = .properties
          studio.sheet = nil
        }
        return
      }
      studio.createRecord(
        title: name, kind: kind,
        category: kind == "entity" ? category : (kind == "capture" ? "Ideas" : ""))
    }
    return SheetScaffold(
      title: "New record", subtitle: "Saved as a draft. A title is optional.", t: studio.t,
      close: close
    ) {
      if let message = creationScope.mismatchMessage(activeWorldID: studio.worldID) {
        Text(message).font(.studio(.caption)).foregroundStyle(studio.t.danger)
      }
      HStack(spacing: 8) {
        ForEach(kinds, id: \.0) { item in
          Button {
            kind = item.0
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              StudioIcon(item.2, size: 15)
                .foregroundStyle(kind == item.0 ? studio.t.accent : studio.t.secondary)
              Text(item.1).font(.studio(size: 13.5, weight: .medium))
              Text(item.3).font(.studio(size: 11.5)).foregroundStyle(studio.t.muted).lineLimit(2)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, alignment: .topLeading).frame(height: 96)
              .background(
                kind == item.0 ? studio.t.accentSoft.opacity(0.6) : studio.t.surface,
                in: RoundedRectangle(cornerRadius: Metric.floatingRadius)
              )
              .overlay(
                RoundedRectangle(cornerRadius: Metric.floatingRadius).stroke(
                  kind == item.0 ? studio.t.accent.opacity(0.6) : studio.t.hairline, lineWidth: 1)
              )
              .contentShape(RoundedRectangle(cornerRadius: Metric.floatingRadius))
          }.buttonStyle(.plain).accessibilityAddTraits(kind == item.0 ? .isSelected : [])
        }
      }
      FormField(
        label: "Title", placeholder: kind == "entity" ? "Name" : "Untitled", text: $name,
        t: studio.t, autofocus: true, submit: create)
      if kind == "entity" {
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text("Type").font(.studio(.captionStrong)).foregroundStyle(studio.t.secondary)
            Spacer()
            Button("Manage types & templates") { managingEntityTypes = true }.buttonStyle(
              QuietButton(t: studio.t, role: .ghost))
          }
          if !types.isEmpty {
            PlainMenu(flexible: true) {
              Button("Freeform category") {
                entityTypeID = nil
                entityTemplateID = nil
              }
              ForEach(types) { type in
                Button(type.name) {
                  entityTypeID = type.id
                  entityTemplateID = nil
                  category = type.name
                }
              }
            } label: {
              StudioLabel(
                types.first { $0.id == entityTypeID }?.name ?? "Freeform category",
                icon: "chevron.down")
            }
          }
          if let entityTypeID {
            PlainMenu {
              Button("Blank profile") { entityTemplateID = nil }
              ForEach(templates.filter { $0.typeID == entityTypeID }) { template in
                Button(template.name) { entityTemplateID = template.id }
              }
            } label: {
              StudioLabel(
                templates.first { $0.id == entityTemplateID }?.name ?? "Blank profile",
                icon: "chevron.down")
            }
          } else {
            FlowLayout(spacing: 6) {
              ForEach(Vocabulary.categories, id: \.self) { item in
                FilterChip(title: item, selected: category == item, t: studio.t) {
                  category = category == item ? "" : item
                }
              }
            }
            FormField(placeholder: "Or enter your own type", text: $category, t: studio.t)
              .accessibilityLabel("Entity type")
          }
        }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Create draft", action: create).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(creationScope.worldID != studio.worldID)
    }
    .studioSheet(isPresented: $managingEntityTypes) {
      EntityTypesSheet(
        studio: studio, worldID: creationScope.worldID, close: { managingEntityTypes = false })
    }
  }
  private var rename: some View {
    let apply = {
      studio.perform {
        if let id = studio.renameTarget ?? studio.conversationID {
          try studio.store.renameConversation(worldID: studio.worldID, id: id, title: name)
          try studio.reload()
        }
        studio.renameTarget = nil
        studio.sheet = nil
      }
    }
    return SheetScaffold(title: "Rename conversation", t: studio.t, width: 400, close: close) {
      FormField(placeholder: "Conversation name", text: $name, t: studio.t) {
        if !nameIsEmpty { apply() }
      }
    } footer: {
      Spacer()
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Button("Rename", action: apply).buttonStyle(QuietButton(t: studio.t, primary: true))
        .keyboardShortcut(.defaultAction).disabled(nameIsEmpty)
    }
  }
}
