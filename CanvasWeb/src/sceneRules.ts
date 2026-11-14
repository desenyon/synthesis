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
