import test from 'node:test';
import assert from 'node:assert/strict';
import { restoredCardSelection } from '../src/sessionSelection.ts';

test('session restores only live existing record groups without selecting their outer frame', () => {
  const elements = [
    {id:'card', customData:{synthesis:'card',recordID:'mira'},groupIds:['own','outer']},
    {id:'text', customData:{synthesis:'part'},groupIds:['own','outer']},
    {id:'other', customData:{synthesis:'card',recordID:'sea'},groupIds:['another','outer']},
    {id:'otherText', customData:{synthesis:'part'},groupIds:['another','outer']},
    {id:'deleted',isDeleted:true,customData:{synthesis:'card',recordID:'mira'}},
  ];
  const original = JSON.stringify(elements);
  assert.deepEqual(restoredCardSelection(elements,['mira','foreign','missing'],new Set(['mira','sea'])),{card:true,text:true});
  assert.deepEqual(restoredCardSelection(elements,['sea'],new Set(['mira'])),{});
  assert.equal(JSON.stringify(elements),original);
});
