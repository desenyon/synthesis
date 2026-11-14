import SwiftUI
import SynthesisCore

/// Deterministic value in 0..<1 for a cell, so patterns never shimmer between redraws.
private func cellNoise(_ x: Int, _ y: Int, _ seed: Int) -> Double {
  var h = UInt64(truncatingIfNeeded: x &* 73_856_093 ^ y &* 19_349_663 ^ seed &* 83_492_791)
  h ^= h >> 13
  h = h &* 0x9E37_79B9_7F4A_7C15
  h ^= h >> 29
  return Double(h % 1000) / 1000
}

/// A segmented bar drawn as a grid of small cells, one glowing block per segment. Shows how a
/// whole divides into parts; here, a world by kind of record.
struct DotMatrixBar: View {
  struct Segment: Identifiable {
    let id: String
    var value: Double
    var color: Color
  }
  let segments: [Segment]
  let t: Theme
  var height: CGFloat = 54
  var body: some View {
    let total = max(1, segments.map(\.value).reduce(0, +))
    GeometryReader { geo in
      let cell = 4.0
      let pitch = 6.0
      let rows = max(1, Int((height - 8) / pitch))
      Canvas { context, size in
        var x = 0.0
        for (index, segment) in segments.enumerated() where segment.value > 0 {
          let width = max(pitch * 2, size.width * segment.value / total)
          let frame = CGRect(
            x: x + 1, y: 1, width: min(width, size.width - x) - 2, height: size.height - 2)
          let shape = Path(roundedRect: frame, cornerRadius: 7)
          context.fill(shape, with: .color(segment.color.opacity(t.dark ? 0.1 : 0.08)))
          let columns = max(1, Int((frame.width - 6) / pitch))
          let inset = (frame.width - Double(columns) * pitch + (pitch - cell)) / 2
          for column in 0..<columns {
            for row in 0..<rows {
              let noise = cellNoise(column, row, index + 1)
              // Denser and brighter toward the top edge, fading into the block.
              let depth = Double(row) / Double(max(1, rows - 1))
              let lit = noise > 0.25 + depth * 0.45 || row == rows - 1
              let level = lit ? (noise > 0.93 ? 1.0 : 0.55 + noise * 0.35) : 0.16
              context.fill(
                Path(
                  CGRect(
                    x: frame.minX + inset + Double(column) * pitch,
                    y: frame.minY + 4 + Double(row) * pitch, width: cell, height: cell)),
                with: .color(noise > 0.97 ? Color.white.opacity(0.9) : segment.color.opacity(level))
              )
            }
          }
          context.stroke(shape, with: .color(segment.color.opacity(0.9)), lineWidth: 1.2)
          x += width
        }
      }
      .frame(width: geo.size.width, height: height)
      // A soft halo in each segment's own colour, as in the reference.
      .background {
        HStack(spacing: 0) {
          ForEach(segments.filter { $0.value > 0 }) { segment in
            RoundedRectangle(cornerRadius: 7).fill(segment.color.opacity(t.dark ? 0.22 : 0.12))
              .frame(width: max(12, geo.size.width * segment.value / total)).blur(radius: 9)
          }
        }
      }
    }.frame(height: height).accessibilityHidden(true)
  }
}

/// Library header: what this world is made of, at a glance. Every number is a real count.
struct WorldComposition: View {
  @ObservedObject var studio: Studio
  private var parts: [(name: String, icon: String, count: Int, color: Color)] {
    let t = studio.t
    var result: [(name: String, icon: String, count: Int, color: Color)] = Vocabulary.categories.map
    {
      category in
      (
        category, categoryIcon(category),
        studio.records.filter { $0.kind != "capture" && $0.category == category }.count,
        t.category(category)
      )
    }
    let filed = Set(Vocabulary.categories)
    result.append(
      (
        "Documents", "doc.text",
        studio.records.filter { $0.kind == "lore" && !filed.contains($0.category) }.count, t.accent
      ))
    result.append(
      (
        "Other entities", "circle.hexagongrid",
        studio.records.filter { $0.kind == "entity" && !filed.contains($0.category) }.count,
        t.secondary
      ))
    result.append(
      ("Ideas", "lightbulb", studio.records.filter { $0.kind == "capture" }.count, t.muted))
    return result.filter { $0.count > 0 }
  }
  var body: some View {
    let t = studio.t
    let parts = parts
    let canon = studio.records.filter { $0.state == "canon" }.count
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(studio.records.count)").font(.system(size: 26, weight: .semibold)).monospacedDigit()
        Text(
          studio.records.count == 1
            ? "record in \(studio.world?.name ?? "this world")"
            : "records in \(studio.world?.name ?? "this world")"
        )
        .font(.system(size: 14)).foregroundStyle(t.secondary)
        Spacer(minLength: 8)
        Text("\(canon) canon · \(studio.records.count - canon) not yet")
          .font(.system(size: 12.5)).foregroundStyle(t.muted)
      }
      DotMatrixBar(
        segments: parts.map { .init(id: $0.name, value: Double($0.count), color: $0.color) }, t: t)
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 170), spacing: 18)], alignment: .leading, spacing: 8
      ) {
        ForEach(parts, id: \.name) { part in
          Button {
            if Vocabulary.categories.contains(part.name) { studio.openLens(part.name) }
          } label: {
            HStack(spacing: 8) {
              Image(systemName: part.icon).font(.system(size: 12)).foregroundStyle(part.color)
                .frame(width: 18)
              Text(part.name).font(.system(size: 13.5))
              Spacer(minLength: 6)
              Text("\(part.count)").font(.system(size: 13)).monospacedDigit().foregroundStyle(
                t.muted)
            }.padding(.horizontal, 6).frame(height: 26).hoverFill(t, radius: 6)
          }.buttonStyle(.plain).disabled(!Vocabulary.categories.contains(part.name))
            .accessibilityLabel("\(part.name): \(part.count)")
        }
      }.padding(.horizontal, -6)
    }.padding(18)
      .background(
        t.surface.opacity(t.dark ? 0.5 : 0.9),
        in: RoundedRectangle(cornerRadius: Metric.panelRadius)
      )
      .overlay(RoundedRectangle(cornerRadius: Metric.panelRadius).stroke(t.hairline, lineWidth: 1))
      .accessibilityElement(children: .contain).accessibilityLabel("World composition")
  }
}

/// Nine-by-nine pixel drawings that dissolve into one another.
private enum PixelArt {
  static let moon = [
    "...###...", "..###....", ".###.....", ".###.....", ".###.....", ".####...#", "..#######",
    "...#####.", "....###..",
  ]
  static let sun = [
    "....#....", ".#.....#.", "...###...", "..#####..", "#.#####.#", "..#####..", "...###...",
    ".#.....#.", "....#....",
  ]
  static func cells(_ rows: [String]) -> Set<Int> {
    var result = Set<Int>()
    for (y, row) in rows.enumerated() {
      for (x, character) in row.enumerated() where character == "#" { result.insert(y * 9 + x) }
    }
    return result
  }
}

/// Draws the moon at progress 0 and the sun at 1; in between, cells switch one by one.
private struct PixelIcon: View, Animatable {
  var progress: Double
  var color: Color
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  var body: some View {
    Canvas { context, size in
      let pitch = size.width / 9
      let moon = PixelArt.cells(PixelArt.moon)
      let sun = PixelArt.cells(PixelArt.sun)
      for index in 0..<81 {
        let threshold = 0.1 + cellNoise(index % 9, index / 9, 7) * 0.8
        let shown = progress < threshold ? moon.contains(index) : sun.contains(index)
        // Cells that are about to change dim first, which reads as a dissolve.
        let near = abs(progress - threshold) < 0.12 && moon.contains(index) != sun.contains(index)
        guard shown || near else { continue }
        context.fill(
          Path(
            CGRect(
              x: Double(index % 9) * pitch + pitch * 0.08,
              y: Double(index / 9) * pitch + pitch * 0.08,
              width: pitch * 0.84, height: pitch * 0.84)),
          with: .color(color.opacity(shown ? (near ? 0.6 : 1) : 0.28)))
      }
    }
  }
}

/// Appearance switch: a glass thumb carrying a pixel moon or sun, with a glow beneath it.
struct PixelThemeToggle: View {
  @ObservedObject var studio: Studio
  var thumb: CGFloat = 26
  var body: some View {
    let dark = studio.dark
    let width = thumb * 2 + 6
    let glow = dark ? Color(hex: 0x9FB4FF) : Color(hex: 0xFFC56B)
    Button {
      withAnimation(.easeInOut(duration: 0.32)) { studio.toggleTheme() }
    } label: {
      ZStack(alignment: dark ? .leading : .trailing) {
        RoundedRectangle(cornerRadius: thumb * 0.42 + 3)
          .fill(dark ? Color.black.opacity(0.55) : Color.black.opacity(0.1))
          .overlay(
            RoundedRectangle(cornerRadius: thumb * 0.42 + 3).stroke(
              studio.t.hairline, lineWidth: 1))
        RoundedRectangle(cornerRadius: thumb * 0.42)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(dark ? 0.24 : 0.95), Color.white.opacity(dark ? 0.08 : 0.7),
              ], startPoint: .top, endPoint: .bottom)
          )
          .overlay(
            RoundedRectangle(cornerRadius: thumb * 0.42).stroke(
              Color.white.opacity(dark ? 0.28 : 0.9), lineWidth: 1)
          )
          .overlay {
            PixelIcon(progress: dark ? 0 : 1, color: dark ? .white : Color(hex: 0xB86E00))
              .frame(width: thumb * 0.58, height: thumb * 0.58)
          }
          // The lit edge under the thumb.
          .overlay(alignment: .bottom) {
            Capsule().fill(glow).frame(width: thumb * 0.7, height: 2).blur(radius: 1.5)
              .offset(y: 1)
          }
          .shadow(color: glow.opacity(dark ? 0.55 : 0.4), radius: 7, y: 3)
          .frame(width: thumb, height: thumb).padding(3)
      }.frame(width: width, height: thumb + 6).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .help(dark ? "Switch to light appearance" : "Switch to dark appearance")
      .accessibilityLabel("Appearance").accessibilityValue(dark ? "Dark" : "Light")
      .accessibilityAddTraits(.isButton)
  }
}
