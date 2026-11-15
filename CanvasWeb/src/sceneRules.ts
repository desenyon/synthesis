/** Shared by the engine adapter and DOM presentation; all positions are webview-local. */
export function cardFrame(card: {
    x: number;
    y: number;
    width: number;
    height: number;
}, state: {
    scrollX: number;
    scrollY: number;
    zoom: {
        value: number;
    };
}) {
    const zoom = state.zoom.value;
    return { x: (card.x + state.scrollX) * zoom, y: (card.y + state.scrollY) * zoom, width: card.width * zoom, height: card.height * zoom, zoom };
}
export function visibleFrame(frame: {
    x: number;
    y: number;
    width: number;
    height: number;
}, width: number, height: number) {
    return frame.x + frame.width >= -40 && frame.y + frame.height >= -40 && frame.x <= width + 40 && frame.y <= height + 40;
}
export function relationDisposition(id: string, source: string | undefined, target: string | undefined, relations: readonly {
    id: string;
    sourceID: string;
    targetID: string;
}[], hidden: ReadonlySet<string>): 'keep' | 'remove' | 'hide' {
    const relation = relations.find(r => r.id === id);
    if (!relation || relation.sourceID !== source || relation.targetID !== target)
        return 'remove';
    return hidden.has(id) ? 'hide' : 'keep';
}
export function acceptsSession(current: string, incoming: unknown) { return current.length > 0 && incoming === current; }
/** Excalidraw stores innermost group first; outer board groups must never own record parts. */
export function cardGroup(element: {
    groupIds?: string[];
}) { return element.groupIds?.[0]; }

/** Test in the rectangle's local axes, including rotated cards. */
export function containsCardPoint(card: { x: number; y: number; width: number; height: number; angle?: number }, point: { x: number; y: number }) {
    const dx = point.x - card.x - card.width / 2;
    const dy = point.y - card.y - card.height / 2;
    const angle = card.angle ?? 0;
    const x = dx * Math.cos(angle) + dy * Math.sin(angle);
    const y = -dx * Math.sin(angle) + dy * Math.cos(angle);
    return Math.abs(x) <= card.width / 2 && Math.abs(y) <= card.height / 2;
}

/** Smooth tangent routing with stable lanes for parallel relationships. */
export function connectionRoute(a: { x: number; y: number; width: number; height: number }, b: { x: number; y: number; width: number; height: number }, lane = 0) {
    const ac = { x: a.x + a.width / 2, y: a.y + a.height / 2 };
    const bc = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    const horizontal = Math.abs(bc.x - ac.x) / ((a.width + b.width) / 2) >= Math.abs(bc.y - ac.y) / ((a.height + b.height) / 2);
    const direction = (horizontal ? bc.x - ac.x : bc.y - ac.y) >= 0 ? 1 : -1;
    const start = horizontal ? { x: ac.x + direction * (a.width / 2 + 6), y: ac.y } : { x: ac.x, y: ac.y + direction * (a.height / 2 + 6) };
    const end = horizontal ? { x: bc.x - direction * (b.width / 2 + 6), y: bc.y } : { x: bc.x, y: bc.y - direction * (b.height / 2 + 6) };
    const dx = end.x - start.x, dy = end.y - start.y;
    // Keep the intermediate points monotonic even when two cards are close. A fixed
    // minimum tangent makes Excalidraw's interpolated path double back into a hook.
    const tangent = Math.abs(horizontal ? dx : dy) / 3 * direction;
    const controlA = horizontal ? [tangent, lane] : [lane, tangent];
    const controlB = horizontal ? [dx - tangent, dy + lane] : [dx + lane, dy - tangent];
    // Excalidraw interpolates through vertices; four cubic control points are NOT
    // four scene vertices. Sample the cubic so steep, short-gap edges cannot loop.
    const sampled: [number, number][] = Array.from({ length: 17 }, (_, i) => {
        const t = i / 16, u = 1 - t;
        return [3*u*u*t*controlA[0] + 3*u*t*t*controlB[0] + t*t*t*dx,
                3*u*u*t*controlA[1] + 3*u*t*t*controlB[1] + t*t*t*dy];
    });
    // The engine sizes arrowheads from the last segment. Keep a readable terminal
    // segment instead of letting dense sampling shrink the direction marker to a dot.
    const points = sampled.filter((p, i) => i === 0 || i === sampled.length - 1 || Math.hypot(dx - p[0], dy - p[1]) >= 24);
    return { start, end, points };
}
