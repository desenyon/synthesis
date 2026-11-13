import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { openDatabase } from '../src/lib/db';
import { Workspace } from '../src/lib/workspace';

const roots: string[] = [];
const connections: ReturnType<typeof openDatabase>[] = [];
function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'worldos-')); roots.push(root);
  const path = join(root, 'test.sqlite');
  const connection = openDatabase(path); connections.push(connection);
  const service = new Workspace(connection.db, 'local');
  const world = service.createWorld('Test world', 'A world for testing');
  return { service, world, path, connection };
}
afterEach(() => { connections.forEach(c => c.sqlite.open && c.sqlite.close()); connections.length = 0; roots.forEach(r => rmSync(r, { recursive: true })); roots.length = 0; });
const draft = { kind: 'lore' as const, title: 'The glass sea', body: 'Moonlight becomes glass.', category: 'Location', tags: ['coast'], aliases: ['Mirror ocean'] };

describe('persistent world memory', () => {
  it('preserves saved content after closing and reopening the database', () => {
    const f = fixture(); const record = f.service.createRecord(f.world.id, draft);
    f.connection.sqlite.close(); const reopened = openDatabase(f.path); connections.push(reopened);
    expect(new Workspace(reopened.db, 'local').getRecord(f.world.id, record.id).body).toBe('Moonlight becomes glass.');
  });
  it('converts capture in place without duplicating it on retry', () => {
    const { service: s, world: w } = fixture();
    const idea = s.createRecord(w.id, { ...draft, kind: 'capture' });
    const page = s.convertCapture(w.id, idea.id);
    expect(s.convertCapture(w.id, idea.id).id).toBe(page.id);
    expect(s.snapshot(w.id).records).toHaveLength(1);
    expect(page.kind).toBe('lore');
  });
  it('searches body, tags and aliases without leaking other worlds or owners', () => {
    const { service: s, world: w, connection } = fixture(); s.createRecord(w.id, draft);
    const other = s.createWorld('Other', ''); s.createRecord(other.id, { ...draft, title: 'Secret glass sea' });
    expect(s.search(w.id, 'Mirror')).toHaveLength(1);
    expect(s.search(w.id, 'coast')[0].title).toBe('The glass sea');
    expect(() => new Workspace(connection.db, 'stranger').snapshot(w.id)).toThrow(/not found/i);
    expect(s.search(w.id, '" OR *')).toEqual([]);
  });
  it('rejects foreign-world links, relationships, events and record lookups', () => {
    const { service: s, world: w } = fixture(); const other = s.createWorld('Other', '');
    const a = s.createRecord(w.id, { ...draft, kind: 'entity' }); const b = s.createRecord(other.id, { ...draft, kind: 'entity' });
    expect(() => s.linkRecords(w.id, a.id, b.id)).toThrow();
    expect(() => s.createRelationship(w.id, a.id, b.id, 'knows')).toThrow();
    expect(() => s.createEvent(w.id, 'Arrival', 'unknown', null, b.id, '')).toThrow();
    expect(() => s.getRecord(w.id, b.id)).toThrow();
  });
  it('rejects stale saves and retains the previous version for restore', () => {
    const { service: s, world: w } = fixture(); const r = s.createRecord(w.id, draft);
    s.saveRecord(w.id, r.id, r.version, { ...draft, body: 'New coast' });
    expect(() => s.saveRecord(w.id, r.id, r.version, draft)).toThrow(/changed/i);
    const old = s.history(w.id, r.id).find(x => x.version === 1)!;
    const restored = s.restore(w.id, r.id, old.id, 2);
    expect(restored.body).toBe('Moonlight becomes glass.'); expect(restored.version).toBe(3);
  });
});

describe('canon approval boundary', () => {
  it('stages AI text without mutating records, then requires exact scoped approval', () => {
    const { service: s, world: w } = fixture(); const r = s.createRecord(w.id, draft);
    const p = s.stageProposal(w.id, { type: 'record', targetId: r.id, record: { ...draft, body: 'The sea is alive.' } }, 'ai-proposed', [{ recordId: r.id, version: 1, quote: 'Moonlight becomes glass.' }], 'Develop the idea');
    expect(s.getRecord(w.id, r.id).body).toBe(draft.body);
    expect(() => s.reviewProposal(w.id, p.id, 'accept', '')).toThrow(/approval/i);
    expect(s.getRecord(w.id, r.id).canonical).toBeNull();
    s.reviewProposal(w.id, p.id, 'accept', p.id);
    expect(s.getRecord(w.id, r.id).canonical?.body).toBe('The sea is alive.');
    expect(() => s.reviewProposal(w.id, p.id, 'accept', p.id)).toThrow(/reviewed/i);
  });
  it('rejects stale approvals and lets rejection leave canon untouched', () => {
    const { service: s, world: w } = fixture(); const r = s.createRecord(w.id, draft);
    const p = s.stageProposal(w.id, { type: 'record', targetId: r.id, record: draft }, 'user-authored', [], 'Promote');
    s.saveRecord(w.id, r.id, 1, { ...draft, body: 'Changed meanwhile' });
    expect(() => s.reviewProposal(w.id, p.id, 'accept', p.id)).toThrow(/changed/i);
    s.reviewProposal(w.id, p.id, 'reject', p.id);
    expect(s.getRecord(w.id, r.id).canonical).toBeNull();
  });
  it('preserves accepted canon when saving or restoring a draft', () => {
    const { service: s, world: w } = fixture(); const r = s.createRecord(w.id, draft);
    const p = s.stageProposal(w.id, { type: 'record', targetId: r.id, record: draft }, 'user-authored', [], 'Promote');
    s.reviewProposal(w.id, p.id, 'accept', p.id);
    const accepted = s.getRecord(w.id, r.id);
    const edited = s.saveRecord(w.id, r.id, accepted.version, { ...draft, body: 'A new hypothesis' });
    expect(edited.state).toBe('draft'); expect(edited.canonical?.body).toBe(draft.body);
  });
  it('rejects unsupported evidence and stages entity and relationship proposals', () => {
    const { service: s, world: w } = fixture(); const a = s.createRecord(w.id, { ...draft, kind: 'entity' });
    const b = s.createRecord(w.id, { ...draft, kind: 'entity', title: 'Mira' });
    expect(() => s.stageProposal(w.id, { type: 'record', targetId: a.id, record: draft }, 'ai-proposed', [{ recordId: a.id, version: 1, quote: 'Invented quote' }], '')).toThrow(/evidence/i);
    const p = s.stageProposal(w.id, { type: 'relationship', sourceId: a.id, targetId: b.id, label: 'protects' }, 'ai-proposed', [], 'Possible connection');
    expect(s.snapshot(w.id).relationships).toHaveLength(0);
    s.reviewProposal(w.id, p.id, 'accept', p.id);
    expect(s.snapshot(w.id).relationships[0].state).toBe('canon');
  });
});
