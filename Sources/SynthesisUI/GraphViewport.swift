import Foundation

/// Screen-space pan relative to the viewport centre. Every zoom control shares this math.
enum GraphViewport {
  static func zoom(scale: Double, pan: CGSize, factor: Double, anchor: CGPoint)
    -> (scale: Double, pan: CGSize)
  {
    guard scale.isFinite, scale > 0, factor.isFinite, factor > 0 else { return (scale, pan) }
    let next = min(2.2, max(0.1, scale * factor))
    let ratio = next / scale
    return (
      next,
      CGSize(
        width: anchor.x - (anchor.x - pan.width) * ratio,
        height: anchor.y - (anchor.y - pan.height) * ratio)
    )
  }
}
