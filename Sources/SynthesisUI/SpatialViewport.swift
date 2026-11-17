import Foundation

/// Screen-space pan relative to the viewport centre. Every zoom control shares this math.
enum SpatialViewport {
  static func zoom(
    scale: Double, pan: CGSize, factor: Double, anchor: CGPoint,
    limits: ClosedRange<Double> = 0.1...2.2
  )
    -> (scale: Double, pan: CGSize)
  {
    guard scale.isFinite, scale > 0, factor.isFinite, factor > 0,
      anchor.x.isFinite, anchor.y.isFinite, pan.width.isFinite, pan.height.isFinite
    else { return (scale, pan) }
    let next = min(limits.upperBound, max(limits.lowerBound, scale * factor))
    let ratio = next / scale
    return (
      next,
      CGSize(
        width: anchor.x - (anchor.x - pan.width) * ratio,
        height: anchor.y - (anchor.y - pan.height) * ratio)
    )
  }
}
