import SwiftUI
import SynthesisCore

private struct EntityPropertyEdit: Identifiable {
  var id: String { field.key }
  var field: EntityField
  var value: EntityValue?
  var profile: EntityProfile
  var inherited: Bool
}

struct EntityPropertiesPage: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  @State private var review: EntityProfileReview?
  @State private var resolved: EntityResolvedType?
  @State private var types: [EntityType] = []
  @State private var editing: EntityPropertyEdit?
  @State private var reviewing = false
  @State private var frozenReview: EntityProfileReview?
  @State private var managing = false
  @State private var template = false
  @State private var history = false
  @State private var showHidden = false
  @State private var showSuggestions = false
  @State private var failure: String?

  var body: some View {
    ScrollView {
      ContentColumn {
        VStack(alignment: .leading, spacing: 24) {
          EntityPageHeading(
            record: record, t: studio.t, subtitle: "Structured details, with room for the unknown.")
          HStack(spacing: 10) {
            PlainMenu(flexible: true) {
              ForEach(types) { type in
                Button(type.name) { assign(type) }
                  .disabled(
                    review?.profile.typeID != type.id && !(review?.profile.values.isEmpty ?? true))
              }
            } label: {
              StudioLabel(resolved?.type.name ?? "Choose an entity type", icon: "chevron.down")
                .lineLimit(1)
            }
            Spacer()
            Button("Manage types") { managing = true }.buttonStyle(
              QuietButton(t: studio.t, role: .ghost))
          }
          if let resolved, let review {
            profileHeader(resolved, review: review)
            if !review.suggestedFields.isEmpty {
              suggestions(review, resolved: resolved)
            }
            VStack(spacing: 0) {
              ForEach(
                resolved.fields.filter {
                  showHidden || review.snapshot.visibleKeys.contains($0.key)
                }
              ) { field in
                propertyRow(field, review: review, resolved: resolved)
              }
            }.background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.panelRadius))
              .overlay(
                RoundedRectangle(cornerRadius: Metric.panelRadius).stroke(
                  studio.t.hairline, lineWidth: 1))
            if resolved.fields.isEmpty {
              Text(
                "This type has no fields yet. Add the details that matter to your world in Manage types."
              )
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
            }
            if review.snapshot.visibleKeys.count < resolved.fields.count {
              Toggle(
                "Show conditional fields (\(resolved.fields.count - review.snapshot.visibleKeys.count) hidden)",
                isOn: $showHidden
              )
              .font(.studio(.caption)).toggleStyle(.checkbox).foregroundStyle(studio.t.secondary)
            }
            HStack(spacing: 10) {
              Button("Save as template") { template = true }.buttonStyle(QuietButton(t: studio.t))
              Button("Property history") { history = true }.buttonStyle(
                QuietButton(t: studio.t, role: .ghost))
              Spacer()
              if review.isCanon {
                Text("Properties accepted").font(.studio(.caption)).foregroundStyle(
                  studio.t.secondary)
              } else {
                Button("Review properties for canon") {
                  frozenReview = review
                  reviewing = true
                }
                .buttonStyle(QuietButton(t: studio.t))
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 10) {
              Text("A profile of your own").font(.studio(size: 20, weight: .medium))
              Text(
                "Define an entity type with reusable fields, or keep writing freely in Overview. Adding properties never changes this entity's existing writing or accepted canon."
              )
              .font(.studio(size: 14)).foregroundStyle(studio.t.secondary).lineSpacing(4)
              Button("Create or choose a type") { managing = true }.buttonStyle(
                QuietButton(t: studio.t))
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
              .background(studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.panelRadius))
          }
          if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
        }.padding(.vertical, 28)
      }
    }
    .onAppear {
      load()
      if studio.captureHint.contains("entity-types") { managing = true }
      if studio.captureHint.contains("properties-review") {
        frozenReview = review
        reviewing = true
      }
      if studio.captureHint.contains("properties-history") { history = true }
      if studio.captureHint == "properties-template" { template = true }
      if ["properties-suggestions", "properties-suggestion-edit"].contains(studio.captureHint) {
        showSuggestions = true
        if studio.captureHint == "properties-suggestion-edit", let review, let resolved,
          let firstField = review.suggestedFields.first
        {
          edit(firstField, review: review, resolved: resolved)
        }
      }
      if let review, let resolved, studio.captureHint.hasPrefix("properties-edit-"),
        let field = resolved.fields.first(where: {
          "properties-edit-" + $0.kind.rawValue == studio.captureHint
        })
      {
        editing = EntityPropertyEdit(
          field: field, value: review.snapshot.values[field.key], profile: review.profile,
          inherited: resolved.defaults[field.key] != nil)
      }
    }
    .onChange(of: studio.worldRevision) { _, _ in load() }
    .studioSheet(item: $editing) { item in
      EntityValueSheet(
        studio: studio, field: item.field, value: item.value, inherited: item.inherited
      ) { value in
        guard item.profile.worldID == studio.worldID, item.profile.recordID == record.id else {
          throw SynthesisError.stale
        }
        var values = item.profile.values
        values[item.field.key] = value
        _ = try studio.store.saveEntityProfile(
          worldID: item.profile.worldID, recordID: item.profile.recordID,
          typeID: item.profile.typeID,
          values: values,
          expectedVersion: item.profile.version)
        try studio.reload()
      } close: {
        editing = nil
      }
    }
    .studioSheet(isPresented: $managing) {
      EntityTypesSheet(studio: studio, close: { managing = false })
    }
    .studioSheet(isPresented: $reviewing) {
      if let frozenReview {
        EntityPropertyCanonSheet(
          studio: studio, record: record, review: frozenReview, close: { reviewing = false })
      }
    }
    .studioSheet(isPresented: $template) {
      if let review {
        EntityTemplateEditor(
          studio: studio, typeID: review.profile.typeID, source: record,
          values: review.profile.values, close: { template = false })
      }
    }
    .studioSheet(isPresented: $history) {
      EntityPropertyHistorySheet(studio: studio, record: record, close: { history = false })
    }
  }
  private func profileHeader(_ resolved: EntityResolvedType, review: EntityProfileReview)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      if !resolved.ancestors.isEmpty {
        Text((resolved.ancestors.map(\.name) + [resolved.type.name]).joined(separator: "  ›  "))
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      }
      if !resolved.type.description.isEmpty {
        Text(resolved.type.description).font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
      }
      Text("Values start as drafts. Accepted properties are frozen separately from your writing.")
        .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
    }
  }
  private func suggestions(_ review: EntityProfileReview, resolved: EntityResolvedType)
    -> some View
  {
    DisclosureGroup("Optional field suggestions", isExpanded: $showSuggestions) {
      FlowLayout(spacing: Space.sm) {
        ForEach(review.suggestedFields) { field in
          Button {
            edit(field, review: review, resolved: resolved)
          } label: {
            StudioLabel(field.label, icon: "pencil.line").lineLimit(1)
          }.buttonStyle(QuietButton(t: studio.t))
            .accessibilityLabel("Edit suggested field, \(field.label)")
        }
      }.padding(.top, Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }.font(.studio(.label))
  }

  private func edit(_ field: EntityField, review: EntityProfileReview, resolved: EntityResolvedType)
  {
    editing = EntityPropertyEdit(
      field: field, value: review.snapshot.values[field.key], profile: review.profile,
      inherited: resolved.defaults[field.key] != nil)
  }

  private func propertyRow(
    _ field: EntityField, review: EntityProfileReview, resolved: EntityResolvedType
  ) -> some View {
    let value = review.snapshot.values[field.key] ?? .unknown
    let hidden = !review.snapshot.visibleKeys.contains(field.key)
    let inherited = review.profile.values[field.key] == nil && resolved.defaults[field.key] != nil
    return HStack(alignment: .top, spacing: 20) {
      VStack(alignment: .leading, spacing: 4) {
        Text(field.label).font(.studio(size: 14, weight: .medium))
        Text(hidden ? "Condition not met" : inherited ? "Inherited default" : field.kind.label)
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
      }.frame(width: 165, alignment: .leading)
      VStack(alignment: .leading, spacing: 5) {
        if case .entity(let id) = value {
          Button {
            studio.perform {
              studio.openRecord(try studio.store.record(worldID: studio.worldID, id: id))
            }
          } label: {
            StudioLabel(
              studio.records.first { $0.id == id }?.title ?? "Open linked entity", icon: "link")
          }
          .buttonStyle(.plain).foregroundStyle(studio.t.accent).font(.studio(size: 14))
        } else if case .entities(let ids) = value {
          if ids.isEmpty {
            Text("None").font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
          }
          ForEach(ids, id: \.self) { id in
            Button {
              studio.perform {
                studio.openRecord(try studio.store.record(worldID: record.worldID, id: id))
              }
            } label: {
              StudioLabel(
                studio.records.first { $0.id == id }?.title ?? "Open archived entity", icon: "link")
            }
            .buttonStyle(.plain).foregroundStyle(studio.t.accent).font(.studio(size: 14))
          }
        } else if case .media(let name, _, let raw) = value, let data = Data(base64Encoded: raw),
          let image = NSImage(data: data)
        {
          Image(nsImage: image).resizable().scaledToFit().frame(maxWidth: 240, maxHeight: 150)
            .clipShape(RoundedRectangle(cornerRadius: Metric.radius)).accessibilityLabel(name)
          Text(name).font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(1)
        } else {
          Text(value.summary).font(.studio(size: 14)).foregroundStyle(
            value == .unknown ? studio.t.secondary : studio.t.text
          )
          .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
        if field.kind == .formula {
          Text(
            field.formula
              + (review.issues[field.key].map { " · " + $0 } ?? "")
          )
          .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      if field.kind != .formula {
        IconButton(icon: "pencil.line", label: "Edit \(field.label)", t: studio.t, size: 28) {
          edit(field, review: review, resolved: resolved)
        }
      }
    }.padding(16).opacity(hidden ? 0.7 : 1)
      .overlay(alignment: .bottom) {
        if field.key != resolved.fields.last?.key {
          Rectangle().fill(studio.t.hairline).frame(height: 1).padding(.horizontal, 16)
        }
      }
  }
  private func load() {
    guard record.worldID == studio.worldID else { return }
    do {
      types = try studio.store.entityTypes(worldID: record.worldID)
      review = try studio.store.entityProfileReview(worldID: record.worldID, recordID: record.id)
      resolved = try review.map {
        try studio.store.resolvedEntityType(worldID: record.worldID, id: $0.profile.typeID)
      }
      failure = nil
    } catch { failure = error.localizedDescription }
  }
  private func assign(_ type: EntityType) {
    do {
      _ = try studio.store.saveEntityProfile(
        worldID: studio.worldID, recordID: record.id, typeID: type.id,
        values: review?.profile.values ?? [:], expectedVersion: review?.profile.version)
      try studio.reload()
    } catch { failure = error.localizedDescription }
  }
}

struct EntityPropertyCanonSheet: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  let review: EntityProfileReview
  let close: () -> Void
  @State private var failure: String?
  var body: some View {
    SheetScaffold(
      title: "Accept property canon", subtitle: record.title + " · " + review.snapshot.typeName,
      t: studio.t, width: 620, close: close
    ) {
      Text(
        "Review the exact values below. Future edits and inherited defaults create a new property draft; this accepted snapshot stays unchanged."
      )
      .font(.studio(size: 14)).foregroundStyle(studio.t.secondary)
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(review.snapshot.fields) { field in
            VStack(alignment: .leading, spacing: 5) {
              Text(field.label).font(.studio(.control))
              if let old = review.profile.canonical?.values[field.key],
                old != review.snapshot.values[field.key]
              {
                Text("Previously: " + displayValue(old)).font(.studio(.caption)).foregroundStyle(
                  studio.t.secondary)
              }
              Text(field.kind.label + (field.kind == .formula ? " · " + field.formula : ""))
                .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              if !review.snapshot.visibleKeys.contains(field.key) {
                Text("Inactive under the current condition")
                  .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              }
              if case .media(let name, _, let raw) = review.snapshot.values[field.key],
                let data = Data(base64Encoded: raw), let image = NSImage(data: data)
              {
                Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 140)
                  .clipShape(RoundedRectangle(cornerRadius: Metric.radius)).accessibilityLabel(name)
              }
              Text(displayValue(review.snapshot.values[field.key] ?? .unknown))
                .font(.studio(size: 14)).fixedSize(horizontal: false, vertical: true)
            }
          }
          if let old = review.profile.canonical {
            ForEach(
              old.fields.filter { prior in !review.snapshot.fields.contains { $0.key == prior.key }
              }
            ) { field in
              Text("Removed field: \(field.label)").font(.studio(size: 14)).foregroundStyle(
                studio.t.danger)
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }.frame(maxHeight: 350)
      if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
    } footer: {
      Button("Cancel", action: close).buttonStyle(QuietButton(t: studio.t, role: .ghost))
      Spacer()
      Button("Accept these properties") {
        do {
          _ = try studio.store.acceptEntityProperties(
            worldID: studio.worldID, recordID: record.id, confirmedProfileID: review.profile.id,
            expectedRevision: review.revision)
          try studio.reload()
          close()
        } catch { failure = error.localizedDescription }
      }.buttonStyle(QuietButton(t: studio.t, primary: true))
    }
  }

  private func displayValue(_ value: EntityValue) -> String {
    switch value {
    case .entity(let id):
      return (try? studio.store.record(worldID: record.worldID, id: id).title)
        ?? "Unavailable entity"
    case .entities(let ids):
      return ids.isEmpty ? "None" : ids.map { displayValue(.entity($0)) }.joined(separator: "; ")
    default:
      return value.summary
    }
  }
}

struct EntityPropertyHistorySheet: View {
  @ObservedObject var studio: Studio
  let record: LoreRecord
  let close: () -> Void
  @State private var revisions: [EntityProfileRevision] = []
  @State private var failure: String?
  var body: some View {
    SheetScaffold(
      title: "Property history",
      subtitle: "Restore starts a new draft and preserves accepted canon.", t: studio.t, width: 580,
      close: close
    ) {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(revisions) { revision in
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Revision \(revision.profile.version)").font(.studio(.control))
                Text(revision.createdAt).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
                Text(revision.profile.values.keys.sorted().joined(separator: ", "))
                  .font(.studio(.caption)).foregroundStyle(studio.t.secondary).lineLimit(2)
              }
              Spacer()
              Button("Restore as draft") {
                do {
                  guard
                    let current = try studio.store.entityProfile(
                      worldID: studio.worldID, recordID: record.id)
                  else { return }
                  _ = try studio.store.restoreEntityProfile(
                    worldID: studio.worldID, recordID: record.id, revisionID: revision.id,
                    expectedVersion: current.version)
                  try studio.reload()
                  close()
                } catch { failure = error.localizedDescription }
              }.buttonStyle(QuietButton(t: studio.t))
            }.padding(12).background(
              studio.t.surface, in: RoundedRectangle(cornerRadius: Metric.radius))
          }
        }
      }.frame(maxHeight: 400)
      if let failure { Text(failure).font(.studio(.caption)).foregroundStyle(studio.t.danger) }
    } footer: {
      Spacer()
      Button("Done", action: close).buttonStyle(QuietButton(t: studio.t))
    }
    .onAppear {
      do {
        revisions = try studio.store.entityProfileHistory(
          worldID: studio.worldID, recordID: record.id)
      } catch { failure = error.localizedDescription }
    }
  }
}
