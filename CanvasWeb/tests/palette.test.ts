import test from 'node:test';
import assert from 'node:assert/strict';
import { displayPalette, palette, displayColor, engineTheme, categoryColor } from '../src/palette.ts';

test('graphite, OLED and light share a display/export palette without changing engine mode', () => {
  assert.equal(displayPalette('dark').background, '#111315');
  assert.equal(displayPalette('oled').background, '#000000');
  assert.equal(displayPalette('light').background, '#e7ecf2');
  assert.equal(engineTheme('oled'), 'dark');
  for (const theme of ['dark', 'oled', 'light'] as const) {
    const actual = displayColor(palette(theme).surface, theme);
    const expected = displayPalette(theme).surface;
    for (const offset of [1,3,5]) {
      assert.ok(Math.abs(parseInt(actual.slice(offset,offset+2),16)-parseInt(expected.slice(offset,offset+2),16)) <= 2);
    }
  }
});

// Regressions: Canvas overlay used unrelated pastel colors, especially illegible in light mode.
test('category aliases retain one readable identity in every appearance', () => {
  const luminance = (hex: string) => {
    const rgb = [1,3,5].map(i => parseInt(hex.slice(i,i+2),16)/255)
      .map(c => c <= .04045 ? c/12.92 : ((c+.055)/1.055)**2.4);
    return rgb[0]*.2126 + rgb[1]*.7152 + rgb[2]*.0722;
  };
  for (const theme of ['dark','oled','light'] as const) {
    const p = displayPalette(theme);
    for (const [canonical, alias] of [['characters','Character'],['factions',' Systems '],['places','Locations'],['power systems','Magic systems'],['events','Historical events']]) {
      assert.equal(categoryColor(p,alias), categoryColor(p,canonical));
      const l1=luminance(categoryColor(p,alias)), l2=luminance(p.surface);
      assert.ok((Math.max(l1,l2)+.05)/(Math.min(l1,l2)+.05) >= 4.5, `${theme} ${alias} contrast`);
    }
    assert.equal(categoryColor(p,'My own category'),p.accent);
  }
});
