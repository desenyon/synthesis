import Foundation
import SynthesisCore
import Testing

@testable import SynthesisUI

struct EntityValueEditorTests {
  @Test func typedEditorRoundTripsWithoutConvertingWorldDatesOrLosingCoordinates() throws {
    let values: [(EntityFieldKind, EntityValue)] = [
      (.text, .text("Notes\nSecond line")), (.number, .number(7.25)), (.boolean, .boolean(false)),
      (.date, .date("Before the third crossing · uncertain")), (.range, .range(-2, 8)),
      (.duration, .duration(3.5, "cycles")), (.selection, .selection("Adept")),
      (.entity, .entity(UUID().uuidString)),
      (.entities, .entities([UUID().uuidString, UUID().uuidString])),
      (.selections, .selections(["Coastal", "High speech"])),
      (.coordinates, .coordinates(-12, 6.25, "sky grid")),
      (.media, .media(name: "reference.png", mime: "image/png", base64: "abc")),
    ]
    for (kind, value) in values {
      let draft = EntityValueDraft(value)
      #expect(try draft.value(for: EntityField(key: "field", label: "Field", kind: kind)) == value)
    }
    var draft = EntityValueDraft(nil)
    draft.primary = "not a number"
    #expect(throws: SynthesisError.self) {
      try draft.value(for: EntityField(key: "number", label: "Number", kind: .number))
    }
    #expect(
      try EntityValueDraft(nil).value(for: EntityField(key: "date", label: "Date", kind: .date))
        == .unknown)
  }
  @Test func tinyAndLargeNumbersRemainVisibleAndEditingPreservesTheirRawValues() throws {
    let field = EntityField(key: "magnitude", label: "Magnitude", kind: .number)
    for value in [1e-8, -1e-8, 5e-24, -2.75e-30, 1e24, -4e30] {
      let display = EntityValue.format(value)
      #expect(display != "0" && display != "-0" && display.lowercased().contains("e"))
      #expect(Double(display) == value)
      #expect(try EntityValueDraft(.number(value)).value(for: field) == .number(value))
    }
    #expect(EntityValue.format(0) == "0")
    #expect(
      try EntityValueDraft(.range(1e-8, 1e24)).value(
        for: EntityField(key: "range", label: "Range", kind: .range)) == .range(1e-8, 1e24))
    let endpoints = EntityValue.range(1e-8, 1e24).summary.components(separatedBy: " – ")
    #expect(endpoints.compactMap(Double.init) == [1e-8, 1e24])
  }

}
