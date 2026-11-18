import { test } from 'node:test';
import assert from 'node:assert/strict';
test('a relationship and its label detour around an intervening card', async () => {
    const { connectionRoute } = await import('../src/sceneRules.ts');
    const a={x:0,y:0,width:300,height:180}, b={...a,x:800}, obstacle={...a,x:400};
    const route=connectionRoute(a,b,0,[obstacle]);
    const inside=(x:number,y:number)=>x>obstacle.x&&x<obstacle.x+obstacle.width&&y>obstacle.y&&y<obstacle.y+obstacle.height;
    assert.ok(route.points.every(p=>!inside(route.start.x+p[0],route.start.y+p[1])));
    assert.ok(!inside(route.middle.x,route.middle.y));
});
test('close parallel connections keep their labels on separate outside curves', async () => {
    const { connectionRoute } = await import('../src/sceneRules.ts');
    const a = {x:0,y:0,width:300,height:180};
    for (const x of [0,12,120,270]) {
        const b = {...a,x};
        const first = connectionRoute(a,b,-30), second = connectionRoute(a,b,30);
        assert.ok(Math.abs(first.middle.y-second.middle.y)>=20);
        assert.ok(first.middle.y<0 && second.middle.y<0);
        assert.equal(first.middle.x,(first.start.x+first.end.x)/2);
    }
});
import { cardFrame, visibleFrame, relationDisposition, acceptsSession, cardGroup, containsCardPoint } from '../src/sceneRules.ts';
import { canvasImageElement, referenceCardElements, selectedCanvasImageID } from '../src/sceneRules.ts';
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

test('moving a saved workspace reference only moves its own active card and parts', () => {
    const link = 'synthesis://reference/event/event-1?world=world-1';
    const make = (id: string, type: string, synthesis: string, group: string) => ({
        id, type, customData: { synthesis }, groupIds: [group, 'outer'],
    });
    const elements = [
        { ...make('deleted', 'rectangle', 'reference', 'ref:deleted'), link, isDeleted: true },
        { ...make('other-card', 'rectangle', 'reference', 'ref:other'), link: link + '-other' },
        { ...make('link-only', 'rectangle', 'card', 'rect:old'), link },
        { ...make('card', 'rectangle', 'reference', 'ref:one'), link },
        make('title', 'text', 'referencePart', 'ref:one'),
        make('other-title', 'text', 'referencePart', 'ref:other'),
        make('ordinary-text', 'text', 'part', 'ref:one'),
    ];
    assert.deepEqual(referenceCardElements(elements, link).map(element => element.id), ['card', 'title']);
});

test('only live image elements backed by board files can become selected image references', () => {
    const files = { 'has-file': {} };
    const elements = [
        { id: 'caption', type: 'text' },
        { id: 'broken', type: 'image', fileId: 'missing' },
        { id: 'removed', type: 'image', fileId: 'has-file', isDeleted: true },
        { id: 'first', type: 'image', fileId: 'has-file' },
        { id: 'second', type: 'image', fileId: 'has-file' },
    ];
    assert.equal(canvasImageElement(elements, files, 'first')?.id, 'first');
    assert.equal(canvasImageElement(elements, files, 'broken'), undefined);
    assert.equal(canvasImageElement(elements, files, 'removed'), undefined);
    assert.equal(selectedCanvasImageID(elements, files, { caption: true, broken: true, first: true }), 'first');
    assert.equal(selectedCanvasImageID(elements, files, { first: true, second: true }), undefined);
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

test('overlapping cards route above the content rather than folding into it', async () => {
    const { connectionRoute } = await import('../src/sceneRules.ts');
    const a = { x: 0, y: 0, width: 300, height: 180 };
    for (const x of [0, 50, 290, 320]) {
        const route = connectionRoute(a, {...a,x}, 0);
        assert.ok(route.points.every(p => p.every(Number.isFinite)));
        assert.ok(route.points.every(p => p[1]+route.start.y < 0));
        assert.ok(Math.hypot(route.end.x-route.start.x,route.end.y-route.start.y)>0);
        assert.ok(Math.min(...route.points.map(p=>p[1]+route.start.y)) < -50);
    }
});


test('Dagre arrangement separates real cards and respects relationship direction', async () => {
    const {arrangeCards} = await import('../src/layout.ts');
    const cards = ['a','b','c'].map(id => ({id,recordID:id,x:0,y:0,width:300,height:210}));
    const result = arrangeCards(cards,[{sourceID:'a',targetID:'b'},{sourceID:'b',targetID:'c'}]);
    assert.equal(result.size,3);
    assert.ok(result.get('b')!.x - result.get('a')!.x >= 300);
    assert.ok(result.get('c')!.x - result.get('b')!.x >= 300);
    assert.deepEqual(cards.map(c=>c.x),[0,0,0], 'layout calculation never mutates saved cards');
});


test('drawing tools never offer styles that change lore-owned cards or images', async () => {
    const { drawingStyleContext } = await import('../src/sceneRules.ts');
    const elements = [
        {id:'card',type:'rectangle',customData:{synthesis:'record'}},
        {id:'edge',type:'arrow',customData:{synthesis:'relation'}},
        {id:'image',type:'image'}, {id:'frame',type:'frame'},
        {id:'note',type:'text'}, {id:'shape',type:'ellipse'},
        {id:'removed',type:'text',isDeleted:true},
    ];
    for (const id of ['card','edge','image','frame','removed']) {
        assert.equal(drawingStyleContext(elements,{[id]:true},'selection').available,false);
    }
    const mixed=drawingStyleContext(elements,{card:true,note:true,edge:true,shape:true},'selection');
    assert.deepEqual(mixed.targets.map(e=>e.id),['note','shape']);
    assert.equal(mixed.available,true);
    assert.equal(mixed.text,false);
    assert.equal(mixed.shapes,false);
    assert.equal(drawingStyleContext(elements,{note:true},'selection').text,true);
    assert.equal(drawingStyleContext(elements,{},'rectangle').shapes,true);
    assert.equal(drawingStyleContext(elements,{},'text').text,true);
    assert.equal(drawingStyleContext(elements,{},'hand').available,false);
    assert.equal(drawingStyleContext(elements,{},undefined).available,false);
});
