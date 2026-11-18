type Size = { width: number; height: number };
export type Viewport = Size & { scrollX: number; scrollY: number; zoom: { value: number } };
export type Viewpoint = { x: number; y: number; zoom: number };
export type ViewportBookmark = Viewpoint & { id: string; name: string };

// Excalidraw's interactive zoom range, including trackpad zoom beyond the Fit range.
export const minimumViewportZoom = 0.1;
export const maximumViewportZoom = 30;
export const viewportBookmarkLimit = 50;
export const viewportBookmarkNameLimit = 80;

function finite(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

/** Board scenes are portable JSON. An absent bookmark list is valid in older boards. */
export function readViewportBookmarks(raw: unknown): ViewportBookmark[] {
  if (!Array.isArray(raw)) return [];
  const ids = new Set<string>();
  const result: ViewportBookmark[] = [];
  for (const entry of raw) {
    if (!entry || typeof entry !== 'object') continue;
    const { id, name, x, y, zoom } = entry;
    const label = typeof name === 'string' ? name.trim() : '';
    if (typeof id !== 'string' || !id || id.length > 80 || ids.has(id) ||
        !label || label.length > viewportBookmarkNameLimit ||
        !finite(x) || !finite(y) || Math.abs(x) > Number.MAX_SAFE_INTEGER / 2 ||
        Math.abs(y) > Number.MAX_SAFE_INTEGER / 2 || !finite(zoom) ||
        zoom < minimumViewportZoom || zoom > maximumViewportZoom) continue;
    result.push({ id, name: label, x, y, zoom });
    ids.add(id);
    if (result.length === viewportBookmarkLimit) break;
  }
  return result;
}

/** Bookmark a world-space center, so restoring into a resize keeps it in view. */
export function captureViewport(state: Viewport): Viewpoint {
  return {
    x: state.width / 2 / state.zoom.value - state.scrollX,
    y: state.height / 2 / state.zoom.value - state.scrollY,
    zoom: state.zoom.value,
  };
}

export function restoreViewport(point: Viewpoint, size: Size) {
  return {
    scrollX: size.width / 2 / point.zoom - point.x,
    scrollY: size.height / 2 / point.zoom - point.y,
    zoom: { value: point.zoom },
  };
}

/** Fit board bounds and the current viewport together into a small, fixed overview. */
export function projectOverview(board: readonly number[], state: Viewport, size: Size) {
  if ((board.length !== 0 && board.length !== 4) || !board.every(finite)) return null;
  const left = -state.scrollX;
  const top = -state.scrollY;
  const viewWidth = state.width / state.zoom.value;
  const viewHeight = state.height / state.zoom.value;
  if (![left, top, viewWidth, viewHeight].every(finite) || viewWidth <= 0 || viewHeight <= 0) return null;
  const minX = Math.min(board[0] ?? left, left);
  const minY = Math.min(board[1] ?? top, top);
  const width = Math.max(board[2] ?? left, left + viewWidth) - minX;
  const height = Math.max(board[3] ?? top, top + viewHeight) - minY;
  const scale = Math.min((size.width - 12) / width, (size.height - 12) / height);
  if (!finite(scale) || scale <= 0) return null;
  const insetX = (size.width - width * scale) / 2;
  const insetY = (size.height - height * scale) / 2;
  const toMap = (x: number, y: number) => ({ x: (x - minX) * scale + insetX, y: (y - minY) * scale + insetY });
  const toScene = (x: number, y: number) => ({ x: (x - insetX) / scale + minX, y: (y - insetY) / scale + minY });
  return {
    toMap,
    toScene,
    viewport: { ...toMap(left, top), width: viewWidth * scale, height: viewHeight * scale },
  };
}
