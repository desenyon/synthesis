# Connected workspace refinement — 2026-11-12

Implemented in the actual native app; gesture acceptance remains open. ConnectedRoot replaces the transient UI study while retaining the graphite foundation. Conversation, curated Canvas, Library/editor, derived Graph, Timeline and Atlas use the same saved world. AI Assisted / Manual is independently persisted and enforced in the native provider core.

## Verified

- `./scripts/check.sh`: strict Swift format lint, 20 tests in 3 suites, optimized build passed.
- Final `./scripts/test.sh`: 20 tests passed after the visual corrections. Final strict lint and `git diff --check` passed.
- `./scripts/verify-ui.sh docs/verification/connected-final`: optimized native build and 27 captures completed at 1440×900, 1920×1080 and 1024×768 (1× bitmap scale). All inspected in contact sheets; canvas, companion and graph also inspected at full size.
- Live native UI: offline message submission and reopening; inline lore citation opens its source; companion shares the saved conversation; Manual preserves editing and canvas; graph neighborhood transfers into a saved independent board; draft creation, body editing, full-text search and reopening; theme and navigation controls; restart preserves draft body, mode, theme, sidebar and selected board.
- Offline transport tests prove Manual blocks requests, cancels in-flight work and rejects queued cancelled work. Canon approval, world isolation, relationship audit/restore, save races, draft flush and malformed-board preservation are covered.

## Limits and next acceptance work

Direct drag automation failed with `noWindowsAvailable` on this borderless window. Node dragging, multi-selection dragging and companion resize gestures are implemented but not live-verified; no frame-rate claim. Atlas/Timeline are reconnected existing features, not exhaustively retested here. Live provider streaming was not called; screenshot responses are explicitly labeled authored examples in an isolated database, not fabricated model success. Structured multi-record proposals, rich image/canvas responses and agent tool loops remain future work.

Next: finish hardware gesture/performance acceptance, then structured reviewable proposal cards. Detailed evidence: [Connected review](verification/CONNECTED_REVIEW.md). Prior UI-study evidence is historical. AGENTS initial-experience paragraph was updated to the owner's connected-workspace directive; canon/privacy requirements were unchanged. Development only: no releases, push or paid provider calls.
