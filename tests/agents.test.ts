import { afterEach, describe, expect, it } from 'vitest';
import { openDatabase } from '../src/lib/db';
import { Workspace } from '../src/lib/workspace';
import { runAgent, type Provider } from '../src/lib/agents/service';
const connections: ReturnType<typeof openDatabase>[] = [];
function setup() { const c = openDatabase(':memory:'); connections.push(c); const s = new Workspace(c.db, 'local'); const w = s.createWorld('A', ''); const r = s.createRecord(w.id, { kind: 'lore', title: 'Tides', body: 'The sea rises at dawn.', category: 'Rule', tags: [], aliases: [] }); return { s, w, r }; }
afterEach(() => { connections.forEach(c => c.sqlite.close()); connections.length = 0; });
describe('proposal-only agent orchestration', () => {
  it('returns grounded suggestions and stages rather than accepting', async () => {
    const { s, w, r } = setup();
    const provider: Provider = { generate: async () => ({ answer: 'Consider a second tide.', evidence: [{ recordId: r.id, version: 1, quote: 'The sea rises at dawn.' }], proposal: { type: 'record', targetId: r.id, record: { kind: 'lore', title: 'Tides', body: 'Two tides.', category: 'Rule', tags: [], aliases: [] } }, reason: 'A possible revision' }) };
    const result = await runAgent(s, w.id, 'Develop', 'Expand the tides', r.id, provider);
    expect(result.proposal?.state).toBe('pending'); expect(s.getRecord(w.id, r.id).body).toBe('The sea rises at dawn.'); expect(s.getRecord(w.id, r.id).canonical).toBeNull();
  });
  it('rejects fabricated citations without modifying data', async () => { const { s,w,r } = setup(); const provider: Provider = { generate: async () => ({ answer:'Claim', evidence:[{ recordId:r.id,version:1,quote:'invented' }], proposal:null, reason:'' }) }; await expect(runAgent(s,w.id,'Critique','Check',r.id,provider)).rejects.toThrow(/evidence/i); expect(s.snapshot(w.id).proposals).toHaveLength(0); });
  it('rejects target changes while a model request is in flight', async () => { const {s,w,r}=setup(); const provider: Provider = { generate: async () => { s.saveRecord(w.id,r.id,1,{kind:'lore',title:'Tides',body:'New writing',category:'Rule',tags:[],aliases:[]}); return {answer:'New idea',evidence:[],proposal:{type:'record',targetId:r.id,record:{kind:'lore',title:'Tides',body:'AI text',category:'Rule',tags:[],aliases:[]}},reason:''}; } }; await expect(runAgent(s,w.id,'Develop','Expand',r.id,provider)).rejects.toThrow(/changed/i); expect(s.getRecord(w.id,r.id).body).toBe('New writing'); });
  it('does not stage canon changes in critique or simulation modes', async () => { const {s,w,r}=setup(); const provider: Provider={generate:async()=>({answer:'Hypothesis',evidence:[],proposal:{type:'record',targetId:r.id,record:{kind:'lore',title:'Tides',body:'Maybe',category:'Rule',tags:[],aliases:[]}},reason:''})}; await expect(runAgent(s,w.id,'Simulate','What if',r.id,provider)).rejects.toThrow(/mode/i); });
});
