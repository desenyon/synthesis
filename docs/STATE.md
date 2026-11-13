# Product audit and redesign — 2026-11-12

The native app was audited screen by screen and rebuilt on one design system. All six workspaces, the editor, the command palette and every sheet now share chrome, tokens and interaction patterns. The full checklist with causes, fixes and remaining work is [verification/AUDIT.md](verification/AUDIT.md).

## What works, as observed

- Native window with traffic lights, resize, full screen and restored frame; integrated 56-point header with no separate title bar.
- One bar per workspace with the persistent AI Assisted / Manual switch; bars collapse to icons in narrow windows.
- ⌘K command palette; ⌘1–6 workspaces; ⌘\ navigation; ⇧⌘M mode; ⇧⌘N conversation; ⌘N record.
- Conversation: mode explanation, lore references, Markdown with lists, quotes, tables and code, save as AI-proposed draft, rename and archive.
- Canvas: card drag with live connectors, marquee, keyboard, drag-to-connect, group, arrange, undo/redo, board rename/archive/restore, docked or takeover companion.
- Library with full-text search, filters and archive; editor with details inspector and canon review as a line diff.
- Graph with force-directed layout, pan/zoom/drag, docked details and relationship editing; Timeline with edit/remove; Atlas with labelled markers.
- Archive with Undo for records, conversations, boards, events and relationships. Nothing is hard-deleted; archived material is exported.

## Checks run

- `./scripts/check.sh`: strict lint, 32 tests in 3 suites, optimized build — passed.
- `./scripts/verify-ui.sh docs/verification/audit-2026-11-12`: 148 captures at four sizes; contact sheets inspected.
- `./scripts/selftest-ui.sh docs/verification/audit-2026-11-12`: 13 of 13 interaction checks passed.

## Not verified

No live provider call was made, so streaming and stop were not seen against a real model. Trackpad pan and pinch, large boards and graphs, VoiceOver, and light-theme sheets were not checked. The self-test needs its window to be key; if focus is taken during a run it reports the affected checks as skipped rather than passed.

## Next

Structured, reviewable multi-record proposals; inline `@` mentions; a measured large-board and large-graph pass; an accessibility walk-through. AGENTS.md gained four operational rules in section 5 (see LEARNINGS.md); protected sections were not changed. Development only: no release, push or paid call.
