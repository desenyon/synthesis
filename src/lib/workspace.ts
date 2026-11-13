import { and, asc, desc, eq, sql } from 'drizzle-orm';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import type { DB } from './db';
import { DomainError, evidenceSchema, proposalPayload, recordInput, type Evidence, type Origin, type ProposalPayload, type RecordInput } from './contracts';
import { worlds, records, revisions, links, relationships, events, proposals, type Snapshot, type WorldRecord } from './db/schema';
const stamp = () => { const time = new Date().toISOString(); return { createdAt: time, updatedAt: time }; };
const inputOf = (r: WorldRecord): RecordInput => ({ kind: r.kind, title: r.title, body: r.body, category: r.category, tags: r.tags, aliases: r.aliases });
export class Workspace {
  constructor(private db: DB, private ownerId: string) {}
  listWorlds() { return this.db.select().from(worlds).where(eq(worlds.ownerId, this.ownerId)).orderBy(asc(worlds.createdAt)).all(); }
  createWorld(name: string, description: string, demo = false) {
    const input = z.object({ name: z.string().trim().min(1).max(100), description: z.string().max(2000) }).parse({ name, description });
    return this.db.insert(worlds).values({ id: randomUUID(), ownerId: this.ownerId, ...input, demo, ...stamp() }).returning().get();
  }
  getWorld(worldId: string) {
    const world = this.db.select().from(worlds).where(and(eq(worlds.id, worldId), eq(worlds.ownerId, this.ownerId))).get();
    if (!world) throw new DomainError('World not found.', 404); return world;
  }
  getRecord(worldId: string, id: string) {
    this.getWorld(worldId);
    const record = this.db.select().from(records).where(and(eq(records.worldId, worldId), eq(records.id, id))).get();
    if (!record) throw new DomainError('Record not found in this world.', 404); return record;
  }
  snapshot(worldId: string): Snapshot {
    const world = this.getWorld(worldId);
    return { world, records: this.db.select().from(records).where(eq(records.worldId, worldId)).orderBy(asc(records.createdAt)).all(), links: this.db.select().from(links).where(eq(links.worldId, worldId)).all(), relationships: this.db.select().from(relationships).where(eq(relationships.worldId, worldId)).all(), events: this.db.select().from(events).where(eq(events.worldId, worldId)).orderBy(asc(events.sortOrder), asc(events.createdAt)).all(), proposals: this.db.select().from(proposals).where(eq(proposals.worldId, worldId)).orderBy(desc(proposals.createdAt)).all() };
  }
  private remember(r: WorldRecord, reason: string) { this.db.insert(revisions).values({ id: randomUUID(), worldId: r.worldId, recordId: r.id, version: r.version, snapshot: r, reason, ...stamp() }).run(); }
  createRecord(worldId: string, input: RecordInput, origin: Origin = 'user-authored') {
    this.getWorld(worldId); const parsed = recordInput.parse(input);
    return this.db.transaction(() => {
      const r = this.db.insert(records).values({ ...parsed, id: randomUUID(), worldId, origin, state: parsed.kind === 'capture' ? 'idea' : 'draft', version: 1, canonical: null, ...stamp() }).returning().get();
      this.remember(r, 'Created'); return r;
    });
  }
  saveRecord(worldId: string, id: string, version: number, input: RecordInput) {
    const parsed = recordInput.parse(input);
    return this.db.transaction(() => {
      const current = this.getRecord(worldId, id);
      if (current.version !== version) throw new DomainError('This record changed elsewhere. Reload before saving; your local draft is preserved.', 409);
      if (current.kind !== parsed.kind) throw new DomainError('Use capture conversion to change the record kind.');
      const r = this.db.update(records).set({ ...parsed, state: current.kind === 'capture' ? 'idea' : 'draft', origin: 'user-authored', version: version + 1, updatedAt: stamp().updatedAt }).where(and(eq(records.id, id), eq(records.worldId, worldId), eq(records.version, version))).returning().get();
      this.remember(r, 'Saved draft'); return r;
    });
  }
  convertCapture(worldId: string, id: string) {
    return this.db.transaction(() => {
      const r = this.getRecord(worldId, id); if (r.kind === 'lore') return r;
      if (r.kind !== 'capture') throw new DomainError('Only inbox ideas can become lore pages.');
      const result = this.db.update(records).set({ kind: 'lore', state: 'draft', version: r.version + 1, updatedAt: stamp().updatedAt }).where(eq(records.id, id)).returning().get();
      this.remember(result, 'Converted inbox idea to lore'); return result;
    });
  }
  history(worldId: string, id: string) { this.getRecord(worldId, id); return this.db.select().from(revisions).where(and(eq(revisions.worldId, worldId), eq(revisions.recordId, id))).orderBy(desc(revisions.version)).all(); }
  restore(worldId: string, id: string, revisionId: string, version: number) {
    const revision = this.history(worldId, id).find(r => r.id === revisionId);
    if (!revision) throw new DomainError('Revision not found.', 404);
    return this.saveRecord(worldId, id, version, { ...inputOf(revision.snapshot), kind: this.getRecord(worldId, id).kind });
  }
  search(worldId: string, query: string) {
    this.getWorld(worldId);
    const tokens = query.slice(0, 200).match(/[\p{L}\p{N}]+/gu) || [];
    if (!tokens.length) return [];
    const fts = tokens.map(t => `"${t}"*`).join(' AND ');
    const ids = this.db.all<{ id: string }>(sql`SELECT id FROM records_fts WHERE records_fts MATCH ${fts} AND world_id=${worldId} ORDER BY rank LIMIT 40`);
    return ids.map(({ id }) => this.getRecord(worldId, id));
  }
  linkRecords(worldId: string, sourceId: string, targetId: string) {
    this.getRecord(worldId, sourceId); const target = this.getRecord(worldId, targetId);
    if (sourceId === targetId || target.kind !== 'entity') throw new DomainError('Link a different entity.');
    this.db.insert(links).values({ id: randomUUID(), worldId, sourceId, targetId, ...stamp() }).onConflictDoNothing().run();
  }
  createRelationship(worldId: string, sourceId: string, targetId: string, label: string, state: 'draft' | 'canon' = 'draft', origin: Origin = 'user-authored') {
    const source = this.getRecord(worldId, sourceId); const target = this.getRecord(worldId, targetId);
    if (source.kind !== 'entity' || target.kind !== 'entity' || sourceId === targetId) throw new DomainError('Relationships need two different entities.');
    const parsed = z.string().trim().min(1).max(80).parse(label);
    const existing = this.db.select().from(relationships).where(and(eq(relationships.worldId, worldId), eq(relationships.sourceId, sourceId), eq(relationships.targetId, targetId), eq(relationships.label, parsed))).get();
    if (existing) { if (state === 'canon' && existing.state !== 'canon') return this.db.update(relationships).set({ state, origin, updatedAt: stamp().updatedAt }).where(eq(relationships.id, existing.id)).returning().get(); return existing; }
    return this.db.insert(relationships).values({ id: randomUUID(), worldId, sourceId, targetId, label: parsed, state, origin, ...stamp() }).returning().get();
  }
  createEvent(worldId: string, title: string, dateLabel: string, sortOrder: number | null, sourceId: string, body: string) {
    this.getRecord(worldId, sourceId);
    const input = z.object({ title: z.string().trim().min(1).max(160), dateLabel: z.string().trim().max(160), sortOrder: z.number().int().min(-100000000).max(100000000).nullable(), body: z.string().max(20000) }).parse({ title, dateLabel, sortOrder, body });
    return this.db.insert(events).values({ id: randomUUID(), worldId, sourceId, ...input, dateLabel: input.dateLabel || 'unknown', ...stamp() }).returning().get();
  }
  validateEvidence(worldId: string, evidence: Evidence[]) {
    const parsed = z.array(evidenceSchema).max(30).parse(evidence);
    for (const e of parsed) {
      const r = this.getRecord(worldId, e.recordId);
      if (r.version !== e.version || !(r.body.includes(e.quote) || r.canonical?.body.includes(e.quote))) throw new DomainError('Source evidence is missing, changed, or does not contain the quoted text.', 409);
    }
    return parsed;
  }
  stageProposal(worldId: string, input: ProposalPayload, origin: Origin, evidence: Evidence[], reason: string) {
    this.getWorld(worldId); const payload = proposalPayload.parse(input); const checked = this.validateEvidence(worldId, evidence);
    let baseVersion: number | null = null; let before: RecordInput | null = null;
    if (payload.type === 'record') {
      if (payload.record.kind === 'capture') throw new DomainError('Convert an idea into lore before canon review.');
      if (payload.targetId) { const r = this.getRecord(worldId, payload.targetId); if (r.kind !== payload.record.kind) throw new DomainError('A proposal cannot change record kind.'); baseVersion = r.version; before = inputOf(r); }
    } else {
      const a = this.getRecord(worldId, payload.sourceId); const b = this.getRecord(worldId, payload.targetId);
      if (a.kind !== 'entity' || b.kind !== 'entity' || a.id === b.id) throw new DomainError('Relationships need two different entities.');
    }
    return this.db.insert(proposals).values({ id: randomUUID(), worldId, payload, baseVersion, before, origin, evidence: checked, reason: z.string().max(4000).parse(reason), state: 'pending', ...stamp() }).returning().get();
  }
  reviewProposal(worldId: string, id: string, decision: 'accept' | 'reject', approvedProposalId: string) {
    this.getWorld(worldId);
    if (approvedProposalId !== id) throw new DomainError('Explicit approval must identify this exact proposal.');
    return this.db.transaction(() => {
      const p = this.db.select().from(proposals).where(and(eq(proposals.id, id), eq(proposals.worldId, worldId))).get();
      if (!p) throw new DomainError('Proposal not found.', 404);
      if (p.state !== 'pending') throw new DomainError('This proposal was already reviewed.', 409);
      if (decision === 'accept') {
        this.validateEvidence(worldId, p.evidence);
        const payload = p.payload;
        if (payload.type === 'record') {
          let r: WorldRecord;
          if (payload.targetId) { r = this.getRecord(worldId, payload.targetId); if (r.version !== p.baseVersion) throw new DomainError('This record changed after the proposal. Reject it and prepare a new review.', 409); }
          else r = this.createRecord(worldId, payload.record, p.origin);
          const accepted = this.db.update(records).set({ ...payload.record, canonical: payload.record, state: 'canon', origin: p.origin, version: r.version + 1, updatedAt: stamp().updatedAt }).where(eq(records.id, r.id)).returning().get();
          this.remember(accepted, `Accepted proposal ${p.id}`);
        } else this.createRelationship(worldId, payload.sourceId, payload.targetId, payload.label, 'canon', p.origin);
      }
      return this.db.update(proposals).set({ state: decision === 'accept' ? 'accepted' : 'rejected', updatedAt: stamp().updatedAt }).where(eq(proposals.id, id)).returning().get();
    });
  }
  exportWorld(worldId: string) { return { format: 'worldos', schemaVersion: 1, exportedAt: new Date().toISOString(), ...this.snapshot(worldId), revisions: this.db.select().from(revisions).where(eq(revisions.worldId, worldId)).all() }; }
}
