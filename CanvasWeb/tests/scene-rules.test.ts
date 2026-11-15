import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cardFrame, visibleFrame, relationDisposition, acceptsSession, cardGroup, containsCardPoint } from '../src/sceneRules.ts';
test('overlay stays attached through pan, zoom and a nonzero webview offset', () => {
    assert.deepEqual(cardFrame({ x: 100, y: 80, width: 300, height: 180 }, { scrollX: -20, scrollY: 10, zoom: { value: 1.5 } }), { x: 120, y: 135, width: 450, height: 270, zoom: 1.5 });
});
test('offscreen cards are culled but partially visible cards survive', () => {
    assert.equal(visibleFrame({ x: -200, y: 20, width: 300, height: 180 }, 800, 600), true);
    assert.equal(visibleFrame({ x: 1000, y: 20, width: 300, height: 180 }, 800, 600), false);
});
test('archived and retargeted relationships cannot remain as false lore', () => {
    const relation = { id: 'r', sourceID: 'a', targetID: 'b', label: 'mentors' };
    assert.equal(relationDisposition('r', 'a', 'b', [relation], new Set()), 'keep');
    assert.equal(relationDisposition('r', 'a', 'b', [], new Set()), 'remove');
    assert.equal(relationDisposition('r', 'a', 'c', [relation], new Set()), 'remove');
    assert.equal(relationDisposition('r', 'a', 'b', [relation], new Set(['r'])), 'hide');
});
test('delayed messages must not write into a newly opened board', () => {
    assert.equal(acceptsSession('new-board', 'old-board'), false);
    assert.equal(acceptsSession('new-board', undefined), false);
    assert.equal(acceptsSession('new-board', 'new-board'), true);
});
test('nested board groups keep each record group separate', () => {
    assert.equal(cardGroup({ groupIds: ['card:a', 'board-group'] }), 'card:a');
    assert.equal(cardGroup({ groupIds: ['card:b', 'board-group'] }), 'card:b');
});

test('rotated record hit testing follows the visible card instead of its old bounds', () => {
    const card = {x: 0, y: 0, width: 300, height: 100, angle: Math.PI / 2};
    assert.equal(containsCardPoint(card, {x: 150, y: 180}), true);
    assert.equal(containsCardPoint(card, {x: 20, y: 50}), false);
    assert.equal(containsCardPoint({...card, angle: 0}, {x: 20, y: 50}), true);
});

test('connection routes leave the correct card face and separate parallel relationships', async () => {
    const { connectionRoute } = await import('../src/sceneRules.ts');
    const a = { x: 0, y: 0, width: 300, height: 180 };
    const b = { x: 500, y: 80, width: 300, height: 180 };
    const route = connectionRoute(a, b, 0);
    assert.deepEqual(route.start, { x: 306, y: 90 });
    assert.deepEqual(route.end, { x: 494, y: 170 });
    assert.deepEqual(route.points[0], [0, 0]);
    assert.deepEqual(route.points.at(-1), [188, 80]);
    const steep = connectionRoute(a, {...b, x: 330, y: -200});
    assert.ok(steep.points.every((p,i,all) => i === 0 || p[0] >= all[i-1][0]), 'tight curves must not double back');
    assert.notDeepEqual(connectionRoute(a, b, -24).points, connectionRoute(a, b, 24).points);
    const reverse = connectionRoute(b, a, 0);
    assert.equal(reverse.start.x, 494);
    assert.equal(reverse.end.x, 306);
    assert.ok(reverse.points.every(p => p.every(Number.isFinite)));
});
