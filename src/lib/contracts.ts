import { z } from 'zod';
export const recordInput = z.object({
  kind: z.enum(['lore', 'entity', 'capture']), title: z.string().trim().min(1).max(160),
  body: z.string().max(200000), category: z.string().trim().max(60),
  tags: z.array(z.string().trim().min(1).max(60)).max(30), aliases: z.array(z.string().trim().min(1).max(100)).max(30),
}).strict();
export type RecordInput = z.infer<typeof recordInput>;
export const evidenceSchema = z.object({ recordId: z.string(), version: z.number().int().positive(), quote: z.string().min(1).max(2000) }).strict();
export type Evidence = z.infer<typeof evidenceSchema>;
export const proposalPayload = z.discriminatedUnion('type', [
  z.object({ type: z.literal('record'), targetId: z.string().nullable(), record: recordInput }).strict(),
  z.object({ type: z.literal('relationship'), sourceId: z.string(), targetId: z.string(), label: z.string().trim().min(1).max(80) }).strict(),
]);
export type ProposalPayload = z.infer<typeof proposalPayload>;
export const modes = ['Create', 'Develop', 'Critique', 'Simulate', 'Canonize'] as const;
export type Mode = typeof modes[number];
export type Origin = 'user-authored' | 'ai-proposed' | 'imported' | 'inferred';
export class DomainError extends Error { constructor(message: string, public status = 400) { super(message); } }
