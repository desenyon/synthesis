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

/** Only ordinary authoring elements may be styled; lore cards/edges retain their world identity. */
export function drawingStyleContext<T extends { id: string; type: string; isDeleted?: boolean; customData?: { synthesis?: unknown } | null }>(
    elements: readonly T[], selected: Record<string, boolean>, activeTool: string | undefined
) {
    const shapes = new Set(['rectangle', 'ellipse', 'diamond', 'arrow', 'line', 'freedraw']);
    const supportsStyle = (type: string) => type === 'text' || shapes.has(type);
    const chosen = elements.filter(e => selected[e.id] && !e.isDeleted);
    const targets = chosen.filter(e => !e.customData?.synthesis && supportsStyle(e.type));
    const kinds = targets.length ? targets.map(e => e.type) : chosen.length ? [] : activeTool && supportsStyle(activeTool) ? [activeTool] : [];
    return { targets, available: kinds.length > 0, text: kinds.length > 0 && kinds.every(t => t === 'text'),
        shapes: kinds.length > 0 && kinds.every(t => shapes.has(t)) };
}
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
type CardBounds = { x: number; y: number; width: number; height: number };
export function connectionRoute(a: CardBounds, b: CardBounds, lane = 0, obstacles: CardBounds[] = []) {
    const direct = directRoute(a, b, lane);
    const blocked = obstacles.filter(r => direct.points.some(p =>
        direct.start.x+p[0] > r.x-12 && direct.start.x+p[0] < r.x+r.width+12 &&
        direct.start.y+p[1] > r.y-12 && direct.start.y+p[1] < r.y+r.height+12));
    if (!blocked.length) return direct;
    const ac = {x:a.x+a.width/2,y:a.y+a.height/2}, bc = {x:b.x+b.width/2,y:b.y+b.height/2};
    const horizontal = Math.abs(ac.x-bc.x) >= Math.abs(ac.y-bc.y);
    const low = Math.min(...[a,b,...obstacles].map(r => horizontal ? r.y : r.x));
    const high = Math.max(...[a,b,...obstacles].map(r => horizontal ? r.y+r.height : r.x+r.width));
    const centre = horizontal ? (ac.y+bc.y)/2 : (ac.x+bc.x)/2;
    const side = centre-low <= high-centre ? -1 : 1;
    const start = horizontal ? {x:ac.x,y:side<0?a.y-6:a.y+a.height+6} : {x:side<0?a.x-6:a.x+a.width+6,y:ac.y};
    const end = horizontal ? {x:bc.x,y:side<0?b.y-6:b.y+b.height+6} : {x:side<0?b.x-6:b.x+b.width+6,y:bc.y};
    const outer = (side<0?low:high) + side*(120+Math.abs(lane)+Math.max(0,lane)*2);
    const first = horizontal ? {x:start.x,y:outer} : {x:outer,y:start.y};
    const second = horizontal ? {x:end.x,y:outer} : {x:outer,y:end.y};
    const points: [number,number][] = Array.from({length:25},(_,i): [number,number] => {
        const t=i/24,u=1-t;
        return [u*u*u*start.x+3*u*u*t*first.x+3*u*t*t*second.x+t*t*t*end.x-start.x,
                u*u*u*start.y+3*u*u*t*first.y+3*u*t*t*second.y+t*t*t*end.y-start.y];
    }).filter((p,i)=>i===0||i===24||Math.hypot(end.x-start.x-p[0],end.y-start.y-p[1])>=24);
    return {start,end,points,middle:{x:(start.x+3*first.x+3*second.x+end.x)/8,y:(start.y+3*first.y+3*second.y+end.y)/8}};
}
function directRoute(a: CardBounds, b: CardBounds, lane = 0) {
    const ac = { x: a.x + a.width / 2, y: a.y + a.height / 2 };
    const bc = { x: b.x + b.width / 2, y: b.y + b.height / 2 };
    const horizontal = Math.abs(bc.x - ac.x) / ((a.width + b.width) / 2) >= Math.abs(bc.y - ac.y) / ((a.height + b.height) / 2);
    const direction = (horizontal ? bc.x - ac.x : bc.y - ac.y) >= 0 ? 1 : -1;
    let start = horizontal ? { x: ac.x + direction * (a.width / 2 + 6), y: ac.y } : { x: ac.x, y: ac.y + direction * (a.height / 2 + 6) };
    let end = horizontal ? { x: bc.x - direction * (b.width / 2 + 6), y: bc.y } : { x: bc.x, y: bc.y - direction * (b.height / 2 + 6) };
    const gap = (horizontal ? end.x - start.x : end.y - start.y) * direction;
    if (gap < 36) {
        // Closely packed or overlapping cards connect around their outside boundary.
        // Facing-port tangents reverse direction in this case and form an illegible knot.
        const coincident = Math.abs(ac.x - bc.x) < 24;
        start = { x: ac.x - (coincident ? a.width / 4 : 0), y: a.y - 6 };
        end = { x: bc.x + (coincident ? b.width / 4 : 0), y: b.y - 6 };
        const top = Math.min(a.y, b.y) - 90 - Math.abs(lane) - Math.max(0, lane) * 2;
        const dx = end.x - start.x, dy = end.y - start.y;
        const points: [number, number][] = Array.from({length: 17}, (_, i): [number, number] => {
            const t = i / 16, u = 1 - t;
            return [3*u*t*t*dx + t*t*t*dx,
                3*u*u*t*(top-start.y) + 3*u*t*t*(top-start.y) + t*t*t*dy];
        }).filter((p,i) => i === 0 || i === 16 || Math.hypot(dx-p[0],dy-p[1]) >= 24);
        return {start,end,points,middle:{x:(start.x+end.x)/2,y:(start.y+6*top+end.y)/8}};
    }
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
    return { start, end, points, middle:{x:start.x+(3*controlA[0]+3*controlB[0]+dx)/8,y:start.y+(3*controlA[1]+3*controlB[1]+dy)/8} };
}
