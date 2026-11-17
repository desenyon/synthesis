import { test } from 'node:test';
import assert from 'node:assert/strict';
import { connectionRoute } from '../src/sceneRules.ts';

test('routing 600 connections across a 300-card board stays interactive', () => {
    const cards = Array.from({ length: 300 }, (_, i) => ({ x: (i % 20) * 380, y: Math.floor(i / 20) * 260, width: 300, height: 180 }));
    const start = performance.now();
    let routes = 0;
    for (let i = 0; i < 600; i++) {
        const a = cards[i % 300], b = cards[(i * 7 + 13) % 300];
        if (a === b) continue;
        const near = cards.filter(c => c !== a && c !== b
            && c.x < Math.max(a.x, b.x) + 300 && c.x + 300 > Math.min(a.x, b.x)
            && c.y < Math.max(a.y, b.y) + 180 && c.y + 180 > Math.min(a.y, b.y));
        const route = connectionRoute(a, b, (i % 3 - 1) * 24, near);
        assert.ok(Number.isFinite(route.middle.x) && Number.isFinite(route.middle.y));
        routes++;
    }
    const elapsed = performance.now() - start;
    console.log(`Canvas routing benchmark: ${routes} connections, 300 cards: ${elapsed.toFixed(1)} ms`);
    assert.ok(elapsed < 3000);
});
