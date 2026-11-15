# Handoff — 2026-11-15 connected studio pass

Use `/Users/desenyon/Developer/synthesis` on `main`, `dist/Synthesis.app`. Read AGENTS and STATE. Do not resurrect the old web app, previews, or worktrees. The owner’s untracked DESIGN_AGENT_BRIEF is untouched. The latest request referred to an attachment that did not arrive; the available earlier node reference and brief informed this iteration. Do not claim exact new-reference parity.

## Integration ownership

- `WorkspaceActions.swift`: preserves spatial JSON/images, world-scoped placement/markers, bounded world index. `Proposals.swift`: nine reviewed operations, stale/archived guards, title ambiguity checks. `AgentEngine.swift`: single-shot context + proposals, never automatic canon approval.
- `HarnessTransport.swift`: only Claude/Codex subscription authentication, stripped API environment, isolated scratch folders, no direct API adapter. Async termination stream fixes the Foundation waitUntilExit hang observed in this session. Status deadline 8s, generation 180s, terminate then kill escalation. Codex shell_tool is disabled. Live calls with these new flags have NOT been tested.
- `Studio.resolve`: flush editor/Canvas before domain write; world identity guard; reload worldRevision and live Canvas after placement. Graph/Atlas react to worldRevision. New rule drafts appear in entity details; the dedicated lab remains unfinished.
- `CanvasHost` + App.tsx: explicit board-text -> Library capture, shared relationship editing, persisted scene acknowledgement. Engine remains OSS Excalidraw; custom card/style/tool UI is Synthesis. `cards.ts` and `sceneRules.ts` own sampled cubic relationship routing; arbitrary obstacle avoidance is unfinished.
- `StudioIcon.swift` + Assets/Icons: upstream Lucide 1.73.0 font/ISC/aliases; Canvas uses matching lucide-react. Shared Theme/Components style authored controls. Native window chrome is retained.

## Verification and continuation

Current exact results and commands are in STATE and INTEGRATION_OVERHAUL. Background captures never replace the owner’s running bundle. They require a fresh database, refuse model calls, and keep the window inactive. Native modal sheets are rendered inline in that runner; the actual modal/pointer flow still needs testing. Do not use foreground selftest repeatedly while the owner works.

1. Confirm subscription auth and generation flags live only with permission to spend usage. Extend structured context tracing: retrieved source lists are persisted but the supplemental world-index JSON is not.
2. Extend engine/native tests for Save as idea, relationship inspector and the custom style panel; the reviewed card placement reload path now has an end-to-end background check. Physical pointer/trackpad behavior is separate.
3. Route around intervening cards, handle rotated endpoints/parallel labels, and make PNG export match DOM cards. Compact Fit is currently an overview; text can require zoom.
4. Benchmark large worlds. Large Graph placement is background/cancellable but its algorithm remains quadratic; no performance SLA is demonstrated.
5. Rules Lab/scenarios/canon review; timeline eras and ordering; Atlas map selector/marker dragging; failed-editor-save crash recovery; accessibility.

Retired ignored scaffolds/previews are in `~/Library/Application Support/Synthesis/Development Archives/retired-scaffolds-20261115/`; source also remains in Git. No lore was deleted. AGENTS operational lines now reflect owner-authorized subscription-only operation and retired code. See LEARNINGS for evidence and rollback.
