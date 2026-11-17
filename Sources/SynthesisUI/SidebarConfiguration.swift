import Foundation
import SynthesisCore

enum SidebarSection: String, CaseIterable, Identifiable, Codable {
  case favorites, workspace, explore, world, conversations
  var id: Self { self }
  var title: String { rawValue.capitalized }
}

/// This Mac's navigation arrangement for one universe; no lore or provider state is included.
struct SidebarConfiguration: Codable, Hashable {
  var version = 1
  var sectionOrder = SidebarSection.allCases.map(\.rawValue)
  var hiddenCategories: [String] = []
  var pinnedCategories: [String] = []

  init() {}
  enum CodingKeys: String, CodingKey {
    case version, sectionOrder, hiddenCategories, pinnedCategories
  }
  init(from decoder: Decoder) throws {
    self.init()
    let values = try decoder.container(keyedBy: CodingKeys.self)
    version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
    sectionOrder = try values.decodeIfPresent([String].self, forKey: .sectionOrder) ?? sectionOrder
    hiddenCategories = try values.decodeIfPresent([String].self, forKey: .hiddenCategories) ?? []
    pinnedCategories = try values.decodeIfPresent([String].self, forKey: .pinnedCategories) ?? []
  }

  var sections: [SidebarSection] { sectionOrder.compactMap(SidebarSection.init(rawValue:)) }
  var validated: Self {
    var value = self
    var seen = Set<String>()
    value.sectionOrder = (sectionOrder + SidebarSection.allCases.map(\.rawValue)).filter {
      SidebarSection(rawValue: $0) != nil && seen.insert($0).inserted
    }
    func unique(_ source: [String]) -> [String] {
      var keys = Set<String>()
      return source.filter {
        !Vocabulary.categoryKey($0).isEmpty && keys.insert(Vocabulary.categoryKey($0)).inserted
      }
    }
    value.hiddenCategories = unique(hiddenCategories)
    value.pinnedCategories = unique(pinnedCategories)
    return value
  }
  func isHidden(_ category: String) -> Bool {
    hiddenCategories.contains { Vocabulary.categoryKey($0) == Vocabulary.categoryKey(category) }
  }
  func isPinned(_ category: String) -> Bool {
    pinnedCategories.contains { Vocabulary.categoryKey($0) == Vocabulary.categoryKey(category) }
  }
}

extension Studio {
  var sidebarCategories: [String] {
    var seen = Set<String>()
    return
      (Vocabulary.categories
      + topLevelRecords.filter { $0.kind == "entity" }.map(\.category).sorted()
      + sidebarConfiguration.pinnedCategories + sidebarConfiguration.hiddenCategories).filter {
        !Vocabulary.categoryKey($0).isEmpty && seen.insert(Vocabulary.categoryKey($0)).inserted
      }
  }
  var visibleSidebarCategories: [String] {
    sidebarCategories.filter { !sidebarConfiguration.isHidden($0) }
  }
  func readSidebarConfiguration() throws -> SidebarConfiguration {
    guard let raw = try store.preference("navigation:\(worldID)") else { return .init() }
    guard
      let configuration = try? JSONDecoder().decode(
        SidebarConfiguration.self, from: Data(raw.utf8)),
      configuration.version == 1
    else {
      throw SynthesisError.invalid(
        "Saved navigation could not be read. It is preserved; restore defaults to replace it.")
    }
    return configuration.validated
  }
  func refreshSidebarConfiguration() {
    do {
      sidebarConfiguration = try readSidebarConfiguration()
      sidebarConfigurationError = nil
    } catch {
      sidebarConfiguration = .init()
      sidebarConfigurationError = error.localizedDescription
    }
  }
  func updateSidebarConfiguration(_ change: (inout SidebarConfiguration) -> Void) {
    perform {
      // Read the latest preference so a stale view cannot overwrite a newer customization.
      var next = try readSidebarConfiguration()
      change(&next)
      try writeSidebarConfiguration(next.validated)
    }
  }
  private func writeSidebarConfiguration(_ value: SidebarConfiguration) throws {
    try store.setPreference(
      "navigation:\(worldID)", value: String(decoding: JSONEncoder().encode(value), as: UTF8.self))
    sidebarConfiguration = value
    sidebarConfigurationError = nil
  }
  func restoreSidebarDefaults() {
    perform { try writeSidebarConfiguration(SidebarConfiguration()) }
  }
  func moveSidebarSection(_ section: SidebarSection, by offset: Int) {
    updateSidebarConfiguration { value in
      guard let index = value.sectionOrder.firstIndex(of: section.rawValue),
        value.sectionOrder.indices.contains(index + offset)
      else { return }
      value.sectionOrder.swapAt(index, index + offset)
    }
  }
  func setSidebarCategory(_ category: String, visible: Bool) {
    guard sidebarCategories.contains(category) else { return }
    updateSidebarConfiguration { value in
      value.hiddenCategories.removeAll {
        Vocabulary.categoryKey($0) == Vocabulary.categoryKey(category)
      }
      if !visible { value.hiddenCategories.append(category) }
    }
  }
  func pinSidebarCategory(_ category: String, pinned: Bool) {
    guard sidebarCategories.contains(category) else { return }
    updateSidebarConfiguration { value in
      value.pinnedCategories.removeAll {
        Vocabulary.categoryKey($0) == Vocabulary.categoryKey(category)
      }
      if pinned { value.pinnedCategories.append(category) }
    }
  }
  func movePinnedCategory(_ category: String, by offset: Int) {
    updateSidebarConfiguration { value in
      guard let index = value.pinnedCategories.firstIndex(of: category),
        value.pinnedCategories.indices.contains(index + offset)
      else { return }
      value.pinnedCategories.swapAt(index, index + offset)
    }
  }
}
