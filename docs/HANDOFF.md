# Handoff — 2026-11-17, full expansion in progress

Start here when picking up Synthesis.

Implementation checkpoint [`dd9fd84`](https://github.com/desenyon/synthesis/commit/dd9fd840b204226b46fb6618a1f95c524db1399f) was pushed to `origin/main`; the remote SHA was checked. This follow-up only records that push. Resume from the latest main, keeping the checkpoint's incomplete statuses.

## Linux continuation — 2026-11-17

Source work for #35, #36, #47–48, #67–69 and #347 resumed with owner approval after the runtime exposed only the Linux checkout. Start with [the run record](PROGRESS.md), [the reference guide](DRAG_RECORDS.md) and [the relationship guide](RELATIONSHIPS.md). The original checkpoint below preserves the Mac evidence and error history. The acceptance ledger now has 32 Verified, 18 In progress, 343 Open and 1 Decision needed.

Run the full Mac check and Canvas audit, then inspect the 67-state capture sweep at all three sizes. Confirm physical #35 drop routing in an authorized isolated session.

```sh
SYNTHESIS_CAPTURE_SIZES='1440x900,1024x768,720x800' \
SYNTHESIS_CAPTURE_STATES="$(cat docs/verification/expansion-parallel-checkpoint/capture-states.txt),reference-editor,reference-composer,proposal-faction-batch,relationship-outgoing,relationship-incoming,relationship-metadata-editor,relationship-metadata-inspector,request-pins,request-pins-browser,context-exclusions,context-submitted" \
SYNTHESIS_CANVAS_AUDIT=1 \
./scripts/verify-ui.sh docs/verification/expansion-parallel-final
uv run --with pillow python scripts/contact-sheets.py docs/verification/expansion-parallel-final
```

## Where things are

- Canonical checkout: `/Users/desenyon/Developer/synthesis`, branch `main` (also the GitHub default). Build and open `dist/Synthesis.app` here; no other worktrees are current.
- Releases: v0.0.1, v0.0.2 and v0.0.3 are full GitHub releases with an Apple Silicon ZIP, checksums, license and third-party notices. The app is ad-hoc signed, not notarized. 1.0 is the future public launch.
- License: GPL-3.0 (owner choice, 2026-11-16).
- The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is not agent-owned. Leave it untouched and out of commits.

## Read first

1. [AGENTS.md](../AGENTS.md): the product contract and protected rules (canon approval, archive-not-delete, privacy, verification honesty).
2. [STATE](STATE.md): what is verified, with exact checks.
3. [EXPANSION](EXPANSION.md) and [EXPANSION_SOURCE](EXPANSION_SOURCE.md): all 394 requirements, individual acceptance and exact source. Then [ROADMAP](ROADMAP.md) and [COMPOSER_CONTEXT](COMPOSER_CONTEXT.md).
4. [PARALLEL_WORK](PARALLEL_WORK.md) and the [checkpoint/error record](verification/expansion-parallel-checkpoint/README.md): ownership, stopped workers, exact failed/passing runs, missing wiring and the final capture manifest.
5. [ARCHITECTURE](ARCHITECTURE.md): modules and persistence. This checkpoint adds migrations 0016–0017, portable format v10 and JSON schema 13.

## Active expansion

**Checkpoint frozen by owner request; resume in the new chat.** All 394 requirements remain individually tracked: 32 Verified, 11 In progress, 351 Open. #1–#32 remain verified; no new boxes were ticked in this parallel checkpoint. Final `./scripts/check.sh` passed 334 tests / 81 suites, strict lint and the optimized build. Canvas 18 tests/typecheck passed. The final binary passed the two-process session audit. Failed check11 and all open defects are preserved in the checkpoint record. Final three-size native captures have **not** run.

**Do not publish a release or tag.** The owner requires every expansion item finished before another release, and publication still requires explicit owner authorization. Current v0.0.3 remains unchanged. Do not relaunch the owner's working app or run foreground tests while they work.

All three workers stopped after their narrow fixes. Saved configuration already sets50 agent threads and passes strict validation; the old runtime still rejected a fifth total agent. Recheck the new runtime's capacity and launch the requested parallel team only as supported. Do not silently use other providers or separate CLI processes to evade a limit. Root owns integration/builds/commits; assign distinct source ownership, read-only coordination and independent checker/reviewer roles before mutations.

### Resume here

1. Confirm main/current status and leave `docs/DESIGN_AGENT_BRIEF.md` untouched. Read the checkpoint errors before claiming anything fixed.
2. Assign independent ownership for the remaining #35 reference wiring and for final native inspection of #33/#34/#43/#44/#61–66. The capture manifest has 56 states; the exact quiet three-size command is saved in the checkpoint record. Current-source final images are required before accepting those items.
3. #35 must consolidate direct-source budget counting, implement editor insertion/modern mention rendering, add persistent/undoable Canvas reference cards and image/board drag sources, register its UTI, and test drop precedence/world isolation. Its current core/composer paths compile and pass tests, but this is not full cross-workspace drag-and-drop.
4. After final checks and inspected screenshots, update evidence for each requirement separately, log progress, commit and push. Continue the other 351 Open entries in independent groups; no partial capability counts as complete.

### Saved implementation map

- **#33:** `WorkspaceSession.swift`, `SessionCaptureFixtures.swift`, `SessionProcessAudit.swift`, `scripts/verify-session.sh`, `WorkspaceSessionTests.swift`; coordinated Studio/main, native editor, Graph/Timeline/Conversation and Canvas selection hooks. Sessions are device-only; canon/provider permissions are not snapshots.
- **#34:** core `QuickCapture.swift`; native controller/model/shortcut/fixtures; 9 focused tests; `docs/QUICK_CAPTURE.md`. Normal launches alone register Control–Option–Space. Corrected header/error sizing still needs final captures.
- **#43–44:** `ConversationBranches.swift`, `PromptRecipes.swift`, `ConversationToolsValidation.swift`, migration 0017, `ConversationTools.swift`, Conversation/Composer integration, 12 capture states and core/UI tests. Prefix copies use new message IDs and preserve lineage without copying proposal authority. Recipes retain frozen world scope.
- **#61–66:** entity schema/model/formula/property/media core files, migration 0016, native Properties/type/value editors and world-scope guard, 26 capture states and core/UI tests. Optional types inherit defaults, properties have separate frozen canon, history/import/search/export remain connected. The agent reads permitted property text; model-created schemas/typed-field proposals are not implemented.
- **#35:** `WorldReference.swift`, `WorkspaceReferenceDrag.swift`, `WorldReferenceContextTests.swift`; record/event/artwork/proposal sources; shared Composer/Conversation routing; AssistantContext/AgentEngine and transient Shell/SplitWorkspace/Canvas drop changes. The missing destinations, sources and tests are listed explicitly in the checkpoint record.
- **Shared portability:** archive v10/JSON13 includes schemas, templates, histories, branch lineage and recipes. Null primary keys and historical oversized payloads are rejected. Image export preserves valid PNG bytes and converts other raster input with explicit failure reporting.

`WorkspaceSession.swift` persists device-local presentation and the newest unsent draft atomically. Separate executions of the actual app have written and restored a session through `scripts/verify-session.sh`, with Manual mode and lore unchanged. Native text Undo remains process-local. Graph publishes a layout signature only after its positions finish and ignores late completions after world changes. Focus remains temporary. Preserve these boundaries alongside #31 startup preferences and #32 editor handles.

`StartupWorkspace` is the shared home catalog. `withNavigation` remembers direct routes; history replay persists its destination separately. Manual startup keeps the Library fallback for Conversation. Startup capture roots are reconstructed from preferences, not assigned a destination. Preserve this alongside #33 session restoration.

`RecordCreation.swift` owns guarded creation and linking. Graph, menu and palette use `RecordLinkSheet`; reference links can connect any records, semantic relationships only entities. Re-resolve endpoints before saving. Searchable pickers handle Up/Down and Return. Capture verification dispatches local NSMenu key equivalents without making the window key; it is not physical input coverage.

`NavigationContext` holds tool subpages and optional inspected sources; `ToolNavigation.swift` coalesces their transitions into the same visit/save boundary. Do not clear a still-mounted editor's save callback when replaying tabs. Library filter/sort is Studio state so it survives remount/history. Search collation folds case/diacritics before ordering: locale comparison equated case variants but ordered them inconsistently and broke multi-alias IN queries. Keep the regression.

`AtlasViewSession.swift` retains image-relative framing, marker/region visibility and selection separately from lore. Local preferences are keyed by world/map; history/layouts hold optional visit snapshots. Atlas must reinstall its save callback when loading a map: switching maps keeps the view mounted. Keep unchanged corrupt preferences and recovered copies intact. The capture runner resets ordinary Atlas fixtures before setting custom context states.

`RecordDrag.swift` shares process-local, bounded record addresses across Search, Favorites and Library. Both native editor targets preserve save guards; Canvas placement validates the captured board generation and waits for a save acknowledgment. Drop coordinates use live pan/zoom, existing card groups move without duplication, and model requests/canon are untouched. Keep the palette mounted while hidden during drag; only transient targets may intercept editor/WebKit input. Wider event/image/proposal transfer remains #35.

`SplitWorkspace.swift` uses the shared native editor in both panes, never two views of the same record. Keep both save guards, separate editor handles and focus-sensitive ⌘W/inspector routing. A secondary record remains open when closing the primary. Short windows stack scrollable content and share one composer; narrow bars group utility actions. The secondary address is per-world, preferred width device-wide; layouts and Back/Forward include both. Canvas is still mounted once in the shell. Its exact-fit helper avoids engine floor rounding; short toolbars remain accessible. Capture fixtures clear prior split state so subsequent workspaces are not contaminated.

Activity uses migration 0015. Preserve its transaction triggers, import validation and viewport-noise filtering when extending the archive. Search keeps the materialized FTS CTE; the scale test caught repeated scans without it. Favorites/preferences preserve archived addresses and unreadable data without exposing foreign-world sources. No foreground events, owner-app restart, model allowance or release in this pass.

## Current shape

Native SwiftUI/AppKit app over SQLite, with the Canvas on an embedded offline Excalidraw bundle (`CanvasWeb/` → `Sources/SynthesisUI/CanvasBundle`). Workspaces: Conversation, Canvas, Library and editor, Graph, Timeline, Atlas, Review, Worlds, Settings, Dashboard, plus Mechanics on entities. The assistant is Codex or Claude Code through the creator's own subscription, with no tools or files; Manual mode blocks requests in the core.

0.0.3 added what-if worlds with reviewed merge-back, technique trees, Atlas regions, Timeline views and reordering, extended Review checks, crash recovery, `.synthesis` Finder integration and explicit-click Codex image generation.

Unreleased on main: the supplied World assistant composer reference is implemented across full chat, companions and compact bars. Real lore/map/board/history attachments, local context inspection, per-world persisted scope/exclusions and Explore versus Propose use one core request builder. Restricted context withholds previous messages. Explore discards model proposal blocks in the core; Propose retains explicit review. No API credentials or broader agent filesystem access were introduced. [Usage and boundaries](COMPOSER_CONTEXT.md).

The follow-up chatbox refinement uses the existing app palette and bundled Inter, a single adaptive toolbar, quieter attachment chips and a saved-shortcut hint. Keep Canon protected and provider disclosure below the input; preserve the draft handoff guards when changing presentation. Current evidence is in STATE.

## How to verify

```sh
./scripts/check.sh                       # strict lint, native tests, optimized build
./scripts/verify-session.sh              # two real processes, temporary data, no windows
./scripts/verify-ui.sh /tmp/captures     # background captures of every state
./scripts/selftest-ui.sh /tmp/selftest   # 19 real pointer/key checks; takes focus briefly
cd CanvasWeb && npm test && npm run typecheck
```

Use background captures while the owner works. Foreground self-tests and live-window walkthroughs take focus and need an isolated/authorized session. For those checks use an isolated instance (`SYNTHESIS_DATABASE_PATH` in a temp folder) and capture with `screencapture -l` while it is frontmost; Stage Manager shrinks unfocused windows.

## Open work

- The owner requires the entire expansion and now authorizes parallel workers, coordination and independent checking. Keep non-overlapping source ownership, one build queue and separate evidence for each numbered requirement. Do not count existing partial behavior as completion. Preserve sidebar composition, canon approval and subscription isolation. The saved agent count is 50, but the active runtime currently rejects a fifth total agent; do not claim 50 are running or bypass that limit through other providers or CLI jobs.
- The new composer still needs foreground popover/keyboard, VoiceOver and animation-feel verification. Request context is previewed at Send; historical answers retain source references, not a full immutable workspace-index snapshot.
- A live Codex image generation has never been run; it needs the owner's approval because it spends subscription allowance.
- VoiceOver walkthrough, trackpad feel and animation pacing are unverified.
- Not built: three-way text merge for what-ifs, drag-to-reorder events, assistant proposals for technique requirements and regions, cosmology-specific tools, continuous file sync, notarized distribution.
- The renewed expansion explicitly authorizes graphite with optional OLED (#1); this supersedes the previous content-background choice. It does not authorize relaxing privacy, approval or subscription-only rules.

Next agent: use [RUN_PROMPT](RUN_PROMPT.md).
