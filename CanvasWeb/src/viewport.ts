export type FitInsets = { top: number; right: number; bottom: number; left: number };

/** Preserve the usable area of a short split pane. The engine otherwise rounds fit zoom
 * down to 10% steps, which can discard almost half of a small viewport. */
export function fitOptions(
  bounds: readonly number[], width: number, height: number, insets: FitInsets,
) {
  const availableWidth = Math.max(1, width - insets.left - insets.right);
  const availableHeight = Math.max(1, height - insets.top - insets.bottom);
  const zoom = Math.min(4, Math.max(0.1, 0.94 * Math.min(
    availableWidth / Math.max(1, bounds[2] - bounds[0]),
    availableHeight / Math.max(1, bounds[3] - bounds[1]),
  )));
  return { fitToViewport: true as const, viewportZoomFactor: 0.94,
    canvasOffsets: insets, minZoom: zoom, maxZoom: zoom };
}
