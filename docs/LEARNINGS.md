# Learnings

Instruction changes below are evidence-backed owner corrections and operational fixes; protected canon and privacy rules remain intact.

## Owner-directed correction: complete rebuild

Observation: the owner rejected successive HTML studies that preserved the same black three-pane structure. Evidence: latest explicit complete UI rebuild directive plus four supplied references. Change: AGENTS.md now names Synthesis, specifies a light chat-first native studio, core-enforced AI/Manual modes, optional inspector, native stack and periodic commits/docs. Canon ownership/privacy/history rules remain. This is an explicit owner change, not autonomous relaxation. Validation: inspect instruction diff and verify actual native app in subsequent gates. Rollback: revert the operational diff only if owner changes direction; never silently restore the rejected layout.

## Native toolchain and verification

Observed: default macOS 27 SDK references a SwiftUI macro plugin absent from the installed command-line toolchain. Building with installed macOS 26.5 SDK succeeded. Scripts select that SDK when available; no system configuration was changed. Swift Testing also needs its explicit macro plugin/library flags on this machine (scripts/test.sh).

Observed: NSWindow constrained 1920×1080 captures to the physical display. Native screenshot harness now bypasses screen constraints only in capture mode and verifies logical content dimensions before writing an image. A filename alone is not evidence of viewport size. Round one remains diagnostic, not final 1920 evidence.

## Native interaction pass

Observed: native menu automation sometimes selected a menu item without activating it; Return activated the selected item. Record panels were consolidated into one enum-backed sheet and a direct link-inspector button was added. Verified afterward by linking a newly created page/entity, searching a saved alias and navigating the link. Do not infer a feature works from compilation or a menu's presence.

Independent review reproduced a queued-request cancellation race: cancel before submit's task began still called the transport. A regression test failed, then passed after entry cancellation checks and cancellation propagation. Canon context now projects decoded semantic text instead of truncating JSON containing RTF. Revision restore now includes tags/aliases in the same atomic record save.

## Latest owner UI correction

Owner explicitly rejected the light editorial interface and requested a compact reference-driven canvas UI first. AGENTS initial-experience paragraph now records that direction and pauses feature expansion. Protected canon/privacy/history requirements are unchanged. Evidence: latest owner message and three new reference images. Validation: actual optimized native UI, screenshots and interaction walkthrough. Rollback: owner-directed change only; previous implementation remains at f35e968.

Performance corrections in the UI study: isolate composer draft and viewport state, commit node movement at drag end, and pre-render ASCII scenery. An idle process observation showed 0.0% CPU and 139008 KB RSS; this is not a frame-rate measurement.

Final UI inspection caught clipped starter cards in smaller windows and cards touching the composer. Initial framing now fits visible fragments into the space above the composer; manual pan/zoom remains available. Module-specific starter chips now match their guide questions.

## Connected refinement — 2026-11-12

Owner explicitly authorized connecting the accepted visual foundation to the real model and removing the UI-study restriction. AGENTS initial-experience paragraph was replaced with that direction; canon/privacy boundaries were unchanged. Evidence: the twelve-priority targeted refinement request. Validation: optimized native build, 20 tests including six UI-model regressions, 27 inspected native captures and the observed flows in verification/CONNECTED_REVIEW.md. Rollback: revert only this operational paragraph if the owner changes direction.

Independent review found delayed viewport saves could overwrite newer controllers and companion conversation switching cleared the canvas save guard. Explicit flush now cancels deferred saves; companion chat navigation preserves its workspace/save callback. Tests cover both scenarios, plus mode independence and board layout/undo. Compact composer provider disclosure was restored; Manual no longer changes destination.

Final inspection found graph edges drawn only inside a Canvas closure were absent after asynchronous state refresh. Moving relationship rendering to state-dependent SwiftUI Paths/labels made actual edges visible in the next capture. Window size alone is insufficient evidence of responsive fit: inspect the companion-open state too. Native CUA could click controls and type, but drag returned `noWindowsAvailable`; retain that verification boundary rather than infer gesture success. No additional AGENTS rule was needed.

## Product audit — 2026-11-12

Observation 1: a borderless window removed all window controls and made native drag automation fail with `noWindowsAvailable` for two sessions. Evidence: prior STATE and CONNECTED_REVIEW; after switching to a titled full-size-content window the self-test drags cards and the companion divider (13 of 13 checks, `verification/audit-2026-11-12/selftest.log`).

Observation 2: posted mouse events reached AppKit views and SwiftUI buttons but not `onTapGesture` or `DragGesture` until the window was key in the active app. Evidence: the same self-test failed four gesture checks with `key=false active=false` and passed them with the window key. A gesture test that runs in a background window proves nothing.

Observation 3: `.fixedSize()` on a menu whose label is a user-entered title made the bar wider than its panel and pushed the companion off-screen. Evidence: `companion` captures before and after; fixed by flexible title menus and `ViewThatFits` bars.

Observation 4: a contact-sheet script that matched `light-*.png` silently showed `light-conversation` under the `light` label, which looked like a rendering bug. Evidence: pass-1 sheets. `scripts/contact-sheets.py` now parses names exactly.

Observation 5: an overlay wider than a 1-point divider did not receive drags, and a handle drawn half outside a card lost hover on its outer half. Hit targets must be real layout, not overhang.

Instruction change: AGENTS.md section 5 gained four bullets — use the shared chrome and tokens; keep the titled window; remove by archiving with Undo; verify UI with `verify-ui.sh` and `selftest-ui.sh`, including the focus caveat. No protected section was edited. Validation: `./scripts/check.sh` passed (32 tests), 148 captures inspected, self-test passed. Rollback: delete those four bullets; nothing else depends on them.

## Canvas on Excalidraw and subscription harness — 2026-11-13

Observation 1: Excalidraw's dark theme is a CSS `invert(93%) hue-rotate(180deg)` on the canvas. Colours written by Synthesis looked wrong until they were stored through the inverse of that filter (`CanvasWeb/src/palette.ts`).

Observation 2: WebKit has no `CanvasRenderingContext2D.filter`, which Excalidraw uses to cancel that inversion for pictures; images appeared as negatives until `canvasFilter.ts` supplied it. Evidence: canvas captures before and after.

Observation 3: view caching cannot capture a `WKWebView`, and `screencapture -l` returned a skewed Stage Manager thumbnail for a background window. The runner now composites `takeSnapshot` into the cached frame. WebKit also does not repaint a web view re-attached in an occluded window, so consecutive canvas captures keep one view.

Observation 4: both harnesses follow the proposal contract when asked to change lore (one live request each). Codex reports its answer in one update; Claude Code streams.

Instruction change: AGENTS.md section 5 gained two bullets (canvas bundle workflow and offline rule; harness default and lock-down). No protected section was edited. Validation: `./scripts/check.sh` (45 tests), canvas captures, live harness test. Rollback: delete those two bullets.

## Reference/engine audit — 2026-11-13

Observed defects: stock mobile chrome returned when the companion narrowed the canvas; an overlay below WebKit's canvas layers was invisible; fading the entire card exposed duplicate engine text; files added before `resetScene` disappeared; card ownership based on the outermost group mixed content after grouping; document-level keyboard events did not reach undo with `handleKeyboardGlobally=false`. Fixes follow observed DOM/engine behavior, not assumptions. Six Node tests, five new native boundary tests and 15 background engine/persistence checks cover the repaired paths. Separate desktop/compact screenshots verify the presentation.

Image generation produced valid PNGs, but duplicating their large base64 into legacy plus converted board payload exceeded the existing 12 MB board bound. Bundled high-quality JPEG derivatives are under 1 MB each, with originals retained outside the repo; saved scene/file checks now pass. Uploaded TIFF/HEIC must be decoded and encoded as PNG rather than merely assigned a PNG MIME label.

Background capture must isolate both database and app bundle. The runner now rejects an absent or already-existing database path, uses a no-model transport, and asserts it is neither active nor key. Build/capture succeeds without opening a foreground window. The capture-startup sentinel test verifies existing data is untouched.

AGENTS.md change: none. These concrete implementation lessons belong here and in the architecture/audit ledger. Rollback uses the individual audit commits; retain image normalization, session guards and user data even if visual presentation is revised.

A final run that opened the illustration sheet first tripped the inactive/non-key assertion. Accessory activation policy alone was insufficient. Non-key/main windows alone did not prevent native sheets activating the app. Prohibited activation suppressed sheet rendering, so it was rejected. Final capture uses accessory/non-key windows and `studioSheet` renders the same content inline only for background snapshots. Production and the explicit foreground self-test keep native modal presentation. A later Manual transition still tripped the focus assertion, so the final runner also blocks application activation requests and makes capture windows mouse-transparent below normal windows. Inline sheet captures prove layout only. The picker also needed a 520-point scaffold to contain both thumbnails plus native sheet padding. Failed capture evidence remains in the local audit logs.

Final shutdown review found that termination waited for a flush but always replied `true`, discarding the new failure result. Window close and Quit now honor `flushCanvas()` success. The embedded engine audit withholds a flush acknowledgement, confirms shutdown is blocked, restores the command and confirms a retry succeeds (17 checks total). Actual foreground Quit/Close interaction remains outside this background pass.

## Main consolidation — 2026-11-13

Observation: divergent worktrees and GitHub's feature-branch default made the active product ambiguous; the owner explicitly requested one primary checkout and removal of the others. The reviewed tree was integrated into main while retaining both histories. Uncommitted rules work was checkpointed after formatting fixes; a private Git bundle, original-file copies and SQLite backup protect recovery.

AGENTS.md change: only the first-session operational instruction now names `/Users/desenyon/Developer/synthesis`, `main` and `dist/Synthesis.app`, and marks old worktree/archive launch targets as retired. Protected mission, canon, privacy and approval rules are unchanged. Validation: source-tree equivalence at integration, full strict lint/tests/build in the primary checkout, Git remote/default-branch verification and app launch inspection. Rollback: remove that added operational sentence only if the owner changes the canonical location; recover earlier source through retained history or the private archive.

## 2026-11-15 — connected actions and subscription boundary

Observed: stale proposed edits ignored their base version; generic signed-in status admitted API-only authentication; Foundation waitUntilExit hung an async harness test after child exit. Regression tests reproduced these before fixes. Use a version guard, subscription-specific preflight, and an asynchronous termination handler. Preserve Manual cancellation and reject nonzero process exits even after partial text.

Observed: a proposal placement could update stored JSON without proving the visible engine had reloaded. Added a background native/engine check that approves a placement and probes its actual coordinates after reload; it passed. Moving one nested record group must not move its enclosing group or discard image files. Rules and relationship-only changes must refresh connected views through domain revision, not record text changes alone.

Visual findings: compact editor Details silently hid the inspector; a long sidebar action wrapped; cubic control points interpreted as scene vertices caused arrow hooks. Corrected compact details, shortened the label, and sampled cubic paths. Initial capture state names were silently ignored; unknown states now fail the capture run instead of creating false coverage.

AGENTS changes (operational section 5 only): replaced the stale instruction to preserve legacy/web/previews with their owner-authorized retirement; replaced optional API wording with subscription-only Claude/Codex and authentication checks. Evidence: explicit owner request, deleted unused adapter/scaffold, passing subscription regressions and build. Protected canon/privacy rules are unchanged. Rollback: restore the two prior operational lines only if implementation/product scope is explicitly reverted; use Git history for retired code, not copied preview apps. Validation: full strict formatting/native tests/optimized build and Canvas checks; current counts in STATE.

## 2026-11-15 — Canvas native occlusion

The connected shell applied an opaque `Theme.background` to the workspace above the permanently mounted WKWebView. Its accessibility tree and engine snapshot remained intact while native rendering was covered. The earlier conclusion that the blank live view was only a capture limitation was unsupported. The shell now leaves the Canvas area transparent. Engine-composited captures remain useful for card rendering but do not verify native occlusion or pointer delivery. Live native verification is required before closing this issue. No protected instruction was changed.

## 2026-11-15 — Compact companion and provider recommendation

The 1024×768 contact sheet exposed a clipped non-Canvas companion: only Canvas previously collapsed the global sidebar when docking chat. Apply the same width policy to all content workspaces, with conversation takeover below the usable split width. The Settings capture also exposed an old installed-first “Recommended” badge conflicting with the new Codex label. Recommendation now uses the explicit product preference. Recapture corrected screens; no AGENTS.md change.

## 2026-11-15 — Audit D2 capture compositing

Adding an opaque black inline sheet did not fix the artwork capture: the WebKit compositor treated every pixel matching the canvas backdrop as transparent, including the sheet. The failing intermediate contact sheet exposed this. CaptureSheetAnchor now reports the actual panel bounds to the compositor; those pixels are protected and the canvas receives the scrim. All eight sheet states were recaptured at both sizes and inspected after the change. The real-modal self-test is separate and remains opt-in because it takes focus. AGENTS.md unchanged; this is a capture implementation lesson, not evidence of live modal interaction.

## 2026-11-15 — scoped settings and preserved writing

- Observation: a font preference must not overwrite formatting in saved RTF. The native test installs a 28 pt title, changes writing preferences, and verifies that title remains 28 pt while unformatted writing uses 20 pt.
- Evidence: `PreferenceBehaviorTests.writingPreferencesConfigureNativeEditorWithoutReformattingRichText`; final 94-test run and changed-preference captures in `verification/settings-refinement`.
- World defaults and device defaults need distinct export scope. Archive tests verify portable defaults, old-version imports, exclusion of device/provider values and rollback for malformed world defaults.
- No AGENTS.md change: existing data-integrity and native-verification rules already cover these practices. Rollback is a normal commit revert; no schema migration or destructive data changes were introduced.

## 2026-11-16 — native Dagre and export verification

JavaScriptCore lacks browser structuredClone; Dagre initially fell back silently to a grid. A JSON-only compatibility function and an asymmetric directed-chain layout assertion now verify the actual bundled engine. The app's Canvas export filter also inverted images painted after Excalidraw export in WebKit: export in literal colours, explicitly transform engine shapes for dark mode, and clear the filter before custom card painting. Actual exported PNGs were inspected. Use the repository check/build wrappers (pinned SDK); bare swift build selected an incompatible SDK macro toolchain. No AGENTS.md edit was needed.

## 2026-11-16 — proposal identity and scoped spatial Undo

A successful rule-acceptance test exposed a generic proposal guard treating every `recordID` as lore. Rules need their own scoped active-record validation before comparing the captured revision. Evidence: MechanicsTests and the Mechanics checkpoint. Atlas Undo previously referenced view state, so switching maps could redirect a restore. Capture the original world/map plus expected replacement instead; reject intervening edits. Evidence: AtlasMapTests stale-Undo and world-isolation cases. No AGENTS.md change: these are implementation-specific findings, documented here and in their domain tests.

## 2026-11-16 — sidebar snapshots and occluded animation

Observed: switching from light Graph to dark Conversation while resizing the background capture window retained Graph's old light selection frame. Studio already held the correct destination; an occluded compositor animation had not settled. `ConnectedRoot` now disables animations only for static capture transactions (and system Reduce Motion), while the focused self-test and normal app retain transitions. A targeted four-frame reproduction then passed `scripts/audit-sidebar-captures.py`; contact sheets showed the correct selection in both themes and sizes. The script catches the original stale selection by sampling actual surfaces.

The stress fixture also exposed an invalid sample conversation ID being assigned after switching fixture worlds. Fixing the fixture's world-scoped IDs removed the error sheet; the capture runner now fails immediately on `studio.error` rather than saving a misleading dimmed screenshot. No runtime navigation or approval behavior was relaxed. AGENTS.md is unchanged; this is a verification implementation detail. Rollback: revert the capture-only transaction and pixel checker together if a future macOS rendering change supersedes them.

## 2026-11-16 — 0.0.1 boundaries and interaction corrections

Observed: Graph Fit allowed 10% while zoom buttons clamped to 40%, causing inward jumps on Zoom Out. The shared anchor transform has numeric regressions. Chronology staging rejected references to new proposal lanes; nested approval tests now cover stable parent IDs. Studio acceptance regression caught and fixed the missing-source event path before packaging. Installed Codex feature listing showed memories enabled by default; the transport now disables them and tests flags and environment isolation.

Instruction change: AGENTS section 5 replaces only “Development only: no releases.” with the owner's explicit 0.0.1 development-prerelease authorization, retaining 1.0 as public product launch and all canon/privacy rules. Evidence is the current owner request. No autonomous product-goal change. Rollback: restore that sentence only if the owner withdraws release authorization. Validation is the full check/capture record in STATE; the instruction does not alter runtime permissions.


## 2026-11-16 — Canvas readiness must include the viewport

Observation: the engine audit passed element-position checks, but the 1440×900 capture clipped most cards after repeated reviewed placement/reload. React had not committed `updateScene` app state when `loaded` serialized it, so a native save could persist reset scroll coordinates. Committing reset/update with `flushSync` before acknowledging readiness repaired the real screenshot. Added saved-viewport, approval-viewport and repeated-reload engine checks. Also excluded the hidden Canvas from compact companion captures and native hit testing.

AGENTS.md operational patch: “A Canvas load must commit its viewport before acknowledging readiness; verify repeated load/flush cycles, not only element positions.” Validation: before/after captures in the interaction completion evidence, passing viewport checks and Canvas typecheck/tests/build. No protected rule changed. Rollback: revert that added sentence independently; reverting the implementation requires rerunning the three viewport checks.


## 2026-11-16 — first-fit and verification process isolation

The packaged-app pass found the initial `scrollToContent` path could acknowledge readiness before the fitted viewport committed, even after saved-viewport reload was repaired. A new native/WebKit assertion failed before the fix (`first-fit-red.log`) and passed after applying the same commit boundary to initial fit. This is covered by the existing AGENTS viewport rule; no further instruction change.

Provider/model selection was cached in process-external macOS defaults. That allowed a fixture Studio to overwrite the runtime selection of a different app instance despite using an isolated database. Replaced the cache with lock-protected per-Studio state; SQLite remains the saved settings authority. A two-instance regression asserts independent choices and unchanged host defaults. Final check: 140 native tests/30 suites, lint and optimized build. No owner lore or preferences were modified. No AGENTS change: the existing background-testing and isolation requirements already apply. Rollback is a normal source revert, but must retain equivalent process isolation.

## 2026-11-16 — live window captures and Stage Manager

Observation: the A2 live check (previously blocked by `SCStreamErrorDomain -3812`) now works with `screencapture -x -o -l <CGWindowID>` against an isolated instance driven by System Events key events. One capture returned a 294×310 image: with Stage Manager on, the app's window shrank into the side strip as soon as focus returned to the terminal, while Accessibility still reported the full size. Activating the app and capturing in the same step fixed it. The same live run found two bugs that background captures could not: Return in the welcome sheet did nothing, and the palette ranked "Capture … as an idea" above matching commands.

AGENTS.md operational patch (section 5, verification bullet): "For live-window checks, run an isolated instance (`SYNTHESIS_DATABASE_PATH` in a temp folder), drive it with key events, and capture with `screencapture -l` while it is frontmost; Stage Manager shrinks unfocused windows." Validation: the repeated live run produced full-size dark and light captures and confirmed both fixes. No protected rule changed. Rollback: delete that sentence.

## 2026-11-16 — release wording

Observation: the owner asked that 0.0.1–0.0.3 be full GitHub releases rather than pre-releases, and chose GPL-3.0. AGENTS.md section 5 replaces "Owner-authorized development prereleases begin at 0.0.1; public product launch remains 1.0. Do not imply prereleases are production-ready." with "Owner-authorized 0.0.x versions are published as full GitHub releases (owner instruction, 2026-11-16); the public 1.0 launch remains later. Do not describe 0.0.x builds as production-ready. The project is licensed GPL-3.0." Evidence: the owner's request in this session. No protected rule changed. Rollback: restore the earlier sentence if the owner withdraws the instruction.

## 2026-11-16 — request restrictions and composer handoff

Observed: filtering a previously bounded workspace index lost older explicit attachments; pruning archived exclusions silently re-enabled earlier conversation context; recomputing a truncated placement total hid omitted entries. Separate regressions failed before the fixes and pass in the 174-test final suite. Filter and prioritize before bounds, preserve restriction identities through archive/Undo, and retain actual totals. Invalid preference decoding must not silently expand request access.

The native 1024×768 capture also showed a typed draft replaced by a placeholder. A disappearing composer could persist its old local text after a new shared draft was assigned. Saves and pending debounces now compare against the shared value last observed; the regression and repeated capture pass. Evidence: `verification/composer-context`. These details belong in the core contracts/tests and this ledger; no AGENTS.md change was needed. Rollback: revert the composer/context slice together; preserve the world database and existing migration history.

## 2026-11-17 — expansion #22, search query plan

Observation: adding a LEFT JOIN around FTS made the existing 2,000-record scale test take 26 seconds for 20 searches (limit: 2 seconds). `EXPLAIN QUERY PLAN` showed a virtual-table scan inside the candidate-record loop. Materializing the FTS CTE once produces a single scan and an indexed ID join. The final native run measured about 66 ms for the same 20 searches, and 76 ms for 20 structured queries. The original scale regression remains in place. Library view constraints also run before LIMIT, so a crowded all-record result cannot hide an entity or section that matches the selected tab.

Validation: `LoreSearchTests`, `AdvancedSearchTests`, existing search/scale tests and the complete check script. No AGENTS.md change; this is a local query implementation lesson. Removing the materialization is unsafe without repeating the scale check; the whole feature can be reverted without a schema migration.


## 2026-11-17 — split panes and engine fitting

Observed: short-pane captures collapsed the editor title and left a Canvas board at 10% despite unused space. Give the short writing surface its own scroll container; move shared composers outside both panes. Excalidraw 0.18.1 floors fit zoom in 10-percent steps. Supplying matching min/max zoom calculated from actual content and reserved toolbar bounds preserves its animation and persistence while using the available viewport. Node tests and 37 embedded-engine checks passed; the corrected captures show 20–22% in short panes without clipped tools. Closing a primary document must exclude the already-open secondary from fallback tab selection. No AGENTS.md change; rollback this feature as one slice without touching the world database.

### 2026-11-17 — record drops across native and Canvas surfaces

Background engine checks for expansion #27 confirmed that native drop points must be converted through the engine's live pan/zoom and guarded by its current load token, including after save acknowledgment. Native provider tests use process-local addresses rather than copying lore into the pasteboard. The first contact sheets showed a target/composer overlap in narrow layouts; retaining geometry while hiding the composer during the gesture fixed it in the 33-state final matrix. No AGENTS.md change; the shared drag helper and evidence document carry this bounded implementation detail.

## 2026-11-17 — collation ordering and category lookup

A native #29 capture showed zero Places results for “sea”. An isolated regression reproduced it: the locale comparison equated `Places` and `places` but ordered them differently against `location`, so SQLite IN membership failed with four aliases. Search now folds case/diacritics first, then uses a consistent string order. All four place aliases, title/body matches and the existing structured-search suite pass. No persistent index uses this collation, so no reindex/migration is required. Evidence: `verification/expansion-029/search-before-fix.log`. AGENTS.md unchanged; rollback would restore the broken comparison and fail the new regression.
