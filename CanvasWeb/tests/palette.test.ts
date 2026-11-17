import test from 'node:test';
import assert from 'node:assert/strict';
import { displayPalette, palette, displayColor, engineTheme } from '../src/palette.ts';

test('graphite, OLED and light share a display/export palette without changing engine mode', () => {
  assert.equal(displayPalette('dark').background, '#111315');
  assert.equal(displayPalette('oled').background, '#000000');
  assert.equal(displayPalette('light').background, '#f8f9fb');
  assert.equal(engineTheme('oled'), 'dark');
  for (const theme of ['dark', 'oled', 'light'] as const) {
    const actual = displayColor(palette(theme).surface, theme);
    const expected = displayPalette(theme).surface;
    for (const offset of [1,3,5]) {
      assert.ok(Math.abs(parseInt(actual.slice(offset,offset+2),16)-parseInt(expected.slice(offset,offset+2),16)) <= 2);
    }
  }
});
