# Current state — 2026-11-12

Two bodies of work landed today. The full checklist, causes and evidence are in [verification/AUDIT.md](verification/AUDIT.md).

1. **Product audit and unified redesign.** All six workspaces, the editor, the command palette and every sheet share one design system; native window controls; reversible archive everywhere; canon review as a diff; verified pointer interactions.
2. **Safe AI depth (M3 slice).** Grounded, inspectable context for every answer; AI change sets staged for item-by-item review; `@` mention tokens with autocomplete; quick capture from ⌘K; Markdown import and export.

## What works, as observed

- Native window with traffic lights, resize, full screen and restored frame; one bar per workspace with the persistent AI Assisted / Manual switch.
- Conversation: modes, `@` mentions, Markdown rendering, "Read N records" disclosure, proposal review cards, save as AI-proposed draft.
- Canvas: card drag with live connectors, marquee, keyboard, drag-to-connect, group and arrange, undo/redo, board management, docked or takeover companion.
- Library with full-text search, filters, archive and file drop; editor with details inspector and canon diff review.
- Graph, Timeline and Atlas with editing; archive with Undo for every kind of removal.
- Import Markdown/text; export Markdown folder or full JSON (schema 4, including proposals and recorded context).

## Checks run

- `./scripts/check.sh`: strict lint, 40 tests in 3 suites, optimized build — passed.
- `./scripts/verify-ui.sh`: 148 captures for the audit (four sizes), 10 more for the M3 screens; contact sheets inspected.
- `./scripts/selftest-ui.sh`: 15 of 15 interaction checks passed on the release build.

## Not verified

No live provider call was made. Streaming, stop, and whether a real model follows the proposal contract are unobserved; everything downstream of the model's text is tested with scripted answers. Trackpad pan and pinch, large boards and graphs, VoiceOver, the native file pickers and drag-and-drop import were not exercised.

## Next

See ROADMAP. The branch is pushed to GitHub; nothing is released or deployed.
