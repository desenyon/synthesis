# WorldOS Implementation Plan

> Execute inline using executing-plans and test-driven development. The owner explicitly requested autonomous implementation without design approval pauses.

**Goal:** Deliver the capture-to-connected-lore workflow in a runnable local app.
**Architecture:** Next.js client shell calls validated local API endpoints; domain services use Drizzle/SQLite transactions. Provider adapter has read context and proposal-only output.
**Tech Stack:** Next.js, React, strict TypeScript, Tailwind/CSS, Drizzle, better-sqlite3, Zod, Vitest, Playwright.
**Spec:** ../../../RUN_PROMPT.md and ../../../AGENTS.md; product design in ../../PRODUCT.md.

## Global constraints
- Creator alone approves canon; preserve accepted snapshots and history.
- Scope every record lookup and relationship to its world and local owner.
- No paid calls during validation. Never display stub responses in runtime.
- Bind to loopback; enforce same-origin mutation and local session checks.

## Review focus
- Concurrent/stale saves must fail without overwriting newer work.
- Navigation and refresh must preserve unsaved content or block leaving.
- Foreign-world IDs must not leak or create connections.
- Stale or repeated approvals must not modify canon.
- Failed/invalid provider responses must leave all lore unchanged.

## Tasks
1. [ ] Persistence and domain (`src/lib/db`, `src/lib/workspace.ts`, `tests/workspace.test.ts`): write failing tests for disk reopening, capture conversion idempotency, search isolation, relationship boundaries, revision conflicts and approval-only canon. Implement schema + numbered migrations + transactions. Run `npm test`.
2. [ ] Local HTTP boundary (`src/lib/security.ts`, `src/app/api`): test invalid origin/session; validate commands with Zod; session-authorized reads and writes; conflict errors and JSON export.
3. [ ] Daily UI (`src/components`, `src/app`): write Playwright capture-to-page-to-entity/search flow; implement shell, editor with explicit save plus recoverable local draft, preview, history, inbox and entity links. Run browser test.
4. [ ] Connections: stored typed relations, keyboard-accessible interactive SVG graph, event dates with optional sort order and source links. Extend browser journey to connected records.
5. [ ] Safe AI (`src/lib/agents`, assistant UI): test provider response validation, source checks and pending proposals. Add all five modes, explicit disclosure, missing-provider state, exact before/after review with accept/reject and optimistic concurrency. No live calls during tests.
6. [ ] Verify and document: run typecheck, lint, full tests, production build, browser journey and mobile smoke. Review source for privacy and data integrity; maintain README and all six docs with observed evidence.
