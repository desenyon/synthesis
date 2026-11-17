import SwiftUI
import SynthesisCore

/// A read-only view of the real object, beside the current workspace. Inspecting a reference
/// changes this panel only; opening/editing remains an explicit action.
struct ObjectInspector: View {
  @ObservedObject var studio: Studio
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var data: ObjectInspection?
  @State private var failure: String?
  @State private var recordPicker = false
  private struct Refresh: Hashable {
    var world: String
    var revision: Int
    var target: InspectionTarget
  }
  var body: some View {
    let target = studio.effectiveInspection
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Text("Inspector").font(.studio(.control))
        Spacer(minLength: 0)
        if case .record(let id) = target,
          let record = studio.records.first(where: { $0.id == id })
        {
          RecordFavoriteButton(studio: studio, record: record)
        }
        IconButton(icon: "books.vertical", label: "Inspect a record", t: studio.t) {
          recordPicker = true
        }.disabled(studio.records.isEmpty).popover(isPresented: $recordPicker) {
          SearchableRecordPicker(records: studio.records, t: studio.t) { record in
            studio.inspect(.record(record.id))
            recordPicker = false
          }
        }
        IconButton(icon: "xmark", label: "Close inspector", t: studio.t) {
          studio.toggleWorkspaceInspector()
        }
      }.padding(.horizontal, 16).frame(height: Metric.bar)
      Rectangle().fill(studio.t.hairline).frame(height: 1)
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if studio.inspectionTarget != nil {
            Button("Follow workspace selection") { studio.followInspectionSelection() }
              .buttonStyle(QuietButton(t: studio.t, role: .ghost))
          }
          if let failure {
            Text("Object unavailable").font(.studio(.cardTitle))
            Text(failure).font(.studio(.label)).foregroundStyle(studio.t.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Button("Retry") { load() }.buttonStyle(QuietButton(t: studio.t))
          } else if let data {
            if let image = ImageCache.image(base64: data.artwork) {
              Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: Metric.radius))
                .accessibilityLabel("Artwork for \(data.title)")
            }
            VStack(alignment: .leading, spacing: 8) {
              StudioLabel(data.kind.isEmpty ? "Record" : data.kind, icon: data.icon)
                .font(.studio(.caption)).foregroundStyle(studio.t.secondary)
              Text(data.title).font(.studio(.section)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
              if let state = data.state { StateBadge(state: state, t: studio.t) }
            }
            VStack(alignment: .leading, spacing: 12) {
              ForEach(Array(data.properties.enumerated()), id: \.offset) { _, field in
                HStack(alignment: .top, spacing: 12) {
                  Text(field.name).font(.studio(.caption)).foregroundStyle(studio.t.secondary)
                    .frame(width: 96, alignment: .leading)
                  Text(field.value).font(.studio(.label)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
            if !data.text.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Current text", t: studio.t)
                Text(String(data.text.prefix(1_200)) + (data.text.count > 1_200 ? "…" : ""))
                  .font(.studio(.label)).foregroundStyle(studio.t.secondary)
                  .lineSpacing(4).textSelection(.enabled)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            if !data.references.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "Connected", t: studio.t)
                ForEach(Array(data.references.enumerated()), id: \.offset) { _, link in
                  Button {
                    studio.inspect(link.target)
                  } label: {
                    HStack(spacing: 8) {
                      StudioIcon(link.icon, size: 14).foregroundStyle(studio.t.secondary)
                      VStack(alignment: .leading, spacing: 3) {
                        Text(link.detail).font(.studio(.caption)).foregroundStyle(
                          studio.t.secondary
                        )
                        .lineLimit(2)
                        Text(link.title).font(.studio(.control)).lineLimit(2)
                      }.frame(maxWidth: .infinity, alignment: .leading)
                      StudioIcon("chevron.right", size: 10).foregroundStyle(studio.t.muted)
                    }.padding(8).hoverFill(studio.t)
                  }.buttonStyle(.plain).help("Inspect \(link.title) without leaving this workspace")
                }
              }
            }
            if case .record(let id) = target,
              let record = studio.records.first(where: { $0.id == id })
            {
              HStack(spacing: 8) {
                Button("Open record") { studio.openRecord(record) }
                  .buttonStyle(QuietButton(t: studio.t))
                if studio.mode == .assisted {
                  IconButton(icon: "at", label: "Reference in conversation", t: studio.t) {
                    studio.reference(record)
                  }
                }
              }
            }
          }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      }
    }.frame(maxHeight: .infinity).background { FrostedSurface(t: studio.t, radius: 0) }
      .animation(reduceMotion ? nil : Motion.panelAnimation, value: target)
      .task(id: Refresh(world: studio.worldID, revision: studio.worldRevision, target: target)) {
        load()
      }
      .accessibilityElement(children: .contain).accessibilityLabel("Contextual inspector")
  }
  private func load() {
    do {
      data = try studio.inspectionData(for: studio.effectiveInspection)
      failure = nil
    } catch {
      data = nil
      failure = error.localizedDescription
    }
  }
}
