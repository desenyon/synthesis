import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fitOptions } from '../src/viewport.ts';

test('fit uses the short split pane without quantizing cards down to 10 percent', () => {
  const insets = {top:76, bottom:76, left:32, right:80};
  const fitted = fitOptions([0,0,1100,780], 740, 300, insets);
  const shownHeight = 780 * fitted.minZoom;
  assert.ok(shownHeight >= (300 - 152) * 0.9);
  assert.ok(shownHeight <= 300 - 152);
  assert.ok(1100 * fitted.maxZoom <= 740 - 112);
  assert.equal(fitted.minZoom, fitted.maxZoom);
});

test('fit remains bounded for tiny elements and an occluded viewport', () => {
  const insets = {top:76, bottom:176, left:32, right:80};
  assert.equal(fitOptions([1,1,1,1], 1400, 900, insets).maxZoom, 4);
  assert.equal(fitOptions([0,0,1000,1000], 10, 10, insets).minZoom, 0.1);
});
