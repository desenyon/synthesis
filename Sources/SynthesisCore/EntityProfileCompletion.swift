extension EntityProfileReview {
  /// Suggestions come only from the creator's active schema. A value marked Unknown is deliberate.
  public var suggestedFields: [EntityField] {
    let visible = Set(snapshot.visibleKeys)
    return snapshot.fields.filter {
      visible.contains($0.key) && $0.kind != .formula && snapshot.values[$0.key] == nil
    }
  }
}
