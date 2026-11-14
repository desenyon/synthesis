# Current state — 2026-11-13

Read [HANDOFF.md](HANDOFF.md) for the working details of the newest pieces and what to do next. The audit checklist and its evidence are in [verification/AUDIT.md](verification/AUDIT.md).

## What works, as observed

- One design system across seven workspaces; native window; archive with Undo everywhere.
- **Assistant on your subscription by default**: Claude Code or Codex as a locked-down local harness, OpenAI API key optional. One live request through each harness answered from world context and returned a change set that was staged, not applied.
- Conversation: modes, `@` mentions, sources read, proposal review cards.
- **Canvas on the Excalidraw engine**: free drawing, shapes, text, images and frames, with Synthesis record cards and relationship arrows. The earlier boards convert on first open and the original layout is kept. Verified in the running app: board loads with 4 cards and 3 relationship arrows, conversion is saved, double-click opens a record, returning to Canvas shows the same board, companion docks and resizes.
- Library, editor with canon diff, Graph, Timeline, Atlas, Review (proposals, canon queue, local checks).
- Import Markdown/text; export Markdown folder or full JSON.
- Library opens with a world-composition card (dot-matrix bar of real counts by kind); the appearance switch is a pixel-icon glass toggle. Both follow the owner's 2026-11-13 references and were inspected in dark and light.

## Checks run on this state

- `./scripts/check.sh`: strict lint, 45 tests in 5 suites, optimized build — passed.
- Canvas captures at 1440×900 and 1024×768 (dark, light, rail, companion, Manual) inspected.
- `./scripts/selftest-ui.sh`: 17 of 17 in one run, including card drag (exact delta, arrows attached, saved), "Show on canvas", referencing selected cards and card artwork.
- `./scripts/verify-ui.sh docs/verification/latest`: 78 captures at 1440×900 and 1024×768; every canvas state now renders in background captures.

## Not verified

Excalidraw's own drawing tools beyond what the captures show; the streaming UI and Stop against a live harness in the running app; trackpad gestures; large boards and graphs; VoiceOver.
