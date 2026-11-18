import assert from 'node:assert/strict';
import { test } from 'node:test';
import { captureViewport, projectOverview, readViewportBookmarks, restoreViewport } from '../src/viewportNavigation.ts';

const viewport = { width: 800, height: 400, scrollX: 160, scrollY: -32, zoom: { value: 2 } };

test('a bookmark restores its original world center and zoom even in a different canvas size', () => {
  const view = captureViewport(viewport);
  assert.deepEqual(view, { x: 40, y: 132, zoom: 2 });
  const resized = { width: 600, height: 480 };
  const restored = restoreViewport(view, resized);
  assert.deepEqual(captureViewport({ ...resized, ...restored }), view);
  assert.deepEqual(restoreViewport(view, viewport), {
    scrollX: viewport.scrollX, scrollY: viewport.scrollY, zoom: viewport.zoom,
  });
});

test('bookmark decoding tolerates legacy boards and rejects malformed or duplicate IDs', () => {
  const good = { id: 'start', name: '  Starting point  ', x: 40, y: -80, zoom: 1 };
  assert.deepEqual(readViewportBookmarks(undefined), []);
  const closeup = { ...good, id: 'closeup', name: 'Detail with trackpad zoom', zoom: 8 };
  assert.deepEqual(readViewportBookmarks([closeup]), [closeup]);
  assert.deepEqual(readViewportBookmarks([
    { ...good, zoom: 0 },
    good,
    { ...good, id: 'bad', x: '40' },
    { ...good, id: 'bad2', y: Infinity },
    { ...good, id: 'extreme', x: 1e308, y: -1e308 },
    { ...good, id: 'bad3', name: '  ' },
    { ...good, id: 'bad4', name: 'x'.repeat(81) },
    { ...good, name: 'Duplicate ID' },
    { ...good, id: 'bad5', zoom: 31 },
  ]), [{ ...good, name: 'Starting point' }]);
  assert.equal(readViewportBookmarks(Array.from({ length: 70 }, (_, index) => ({ ...good, id: String(index) }))).length, 50);
});

test('overview maps the same scene points under pan and zoom and includes the current viewport when off-board', () => {
  const map = projectOverview([-320, -100, 500, 500], viewport, { width: 180, height: 84 });
  assert.ok(map);
  const corner = map.toMap(-160, 32);
  assert.equal(map.viewport.x, corner.x);
  assert.equal(map.viewport.y, corner.y);
  const target = map.toScene(corner.x, corner.y);
  assert.ok(Math.abs(target.x + 160) < 1e-9);
  assert.ok(Math.abs(target.y - 32) < 1e-9);
  const far = projectOverview([-320, -100, 500, 500], { ...viewport, scrollX: -90_000 }, { width: 180, height: 84 });
  assert.ok(far);
  assert.ok(far.viewport.x + far.viewport.width <= 180);
  assert.ok(far.toMap(-320, -100).x >= 0);
  assert.equal(projectOverview([Infinity, 0, 100, 100], viewport, { width: 180, height: 84 }), null);
});
