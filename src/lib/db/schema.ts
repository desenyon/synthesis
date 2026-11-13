import { integer, sqliteTable, text } from 'drizzle-orm/sqlite-core';
import type { Evidence, Origin, ProposalPayload, RecordInput } from '../contracts';
const timestamps = () => ({ createdAt: text('created_at').notNull(), updatedAt: text('updated_at').notNull() });
export const worlds = sqliteTable('worlds', {
  id: text('id').primaryKey(), ownerId: text('owner_id').notNull(), name: text('name').notNull(), description: text('description').notNull(), demo: integer('demo', { mode: 'boolean' }).notNull().default(false), ...timestamps(),
});
export const records = sqliteTable('records', {
  id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id),
  kind: text('kind').$type<RecordInput['kind']>().notNull(), title: text('title').notNull(), body: text('body').notNull(), category: text('category').notNull(),
  tags: text('tags', { mode: 'json' }).$type<string[]>().notNull(), aliases: text('aliases', { mode: 'json' }).$type<string[]>().notNull(),
  state: text('state').$type<'idea' | 'draft' | 'canon' | 'hypothetical'>().notNull(), origin: text('origin').$type<Origin>().notNull(),
  canonical: text('canonical', { mode: 'json' }).$type<RecordInput | null>(), version: integer('version').notNull(), ...timestamps(),
});
export const revisions = sqliteTable('revisions', {
  id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id), recordId: text('record_id').notNull().references(() => records.id),
  version: integer('version').notNull(), snapshot: text('snapshot', { mode: 'json' }).$type<typeof records.$inferSelect>().notNull(), reason: text('reason').notNull(), ...timestamps(),
});
export const links = sqliteTable('links', { id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id), sourceId: text('source_id').notNull().references(() => records.id), targetId: text('target_id').notNull().references(() => records.id), ...timestamps() });
export const relationships = sqliteTable('relationships', {
  id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id), sourceId: text('source_id').notNull().references(() => records.id), targetId: text('target_id').notNull().references(() => records.id), label: text('label').notNull(),
  state: text('state').$type<'draft' | 'canon'>().notNull(), origin: text('origin').$type<Origin>().notNull(), ...timestamps(),
});
export const events = sqliteTable('events', {
  id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id), title: text('title').notNull(), dateLabel: text('date_label').notNull(), sortOrder: integer('sort_order'), sourceId: text('source_id').notNull().references(() => records.id), body: text('body').notNull(), state: text('state').notNull().default('draft'), origin: text('origin').notNull().default('user-authored'), ...timestamps(),
});
export const proposals = sqliteTable('proposals', {
  id: text('id').primaryKey(), worldId: text('world_id').notNull().references(() => worlds.id), payload: text('payload', { mode: 'json' }).$type<ProposalPayload>().notNull(),
  baseVersion: integer('base_version'), before: text('before', { mode: 'json' }).$type<RecordInput | null>(),
  evidence: text('evidence', { mode: 'json' }).$type<Evidence[]>().notNull(), reason: text('reason').notNull(), origin: text('origin').$type<Origin>().notNull(),
  state: text('state').$type<'pending' | 'accepted' | 'rejected'>().notNull(), ...timestamps(),
});
export type World = typeof worlds.$inferSelect;
export type WorldRecord = typeof records.$inferSelect;
export type Proposal = typeof proposals.$inferSelect;
export type Revision = typeof revisions.$inferSelect;
export type Snapshot = { world: World; records: WorldRecord[]; links: (typeof links.$inferSelect)[]; relationships: (typeof relationships.$inferSelect)[]; events: (typeof events.$inferSelect)[]; proposals: Proposal[] };
