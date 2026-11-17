# Decisions

## 2026-11-12 — owner-protected product decisions

- Product name: Synthesis. A native macOS application; user allows GPUI or another native implementation.
- Complete replacement of the rejected black three-pane design. Light default, collapsible navigation, central conversational workspace, no fixed AI sidebar, no automatically opened document. Manual mode must remain independently useful and stop model calls.
- AI output never becomes canon without explicit scoped creator approval. Lore, history and privacy safeguards remain protected.
- Owner update (2026-11-16): development prereleases beginning at 0.0.1 are authorized after checks; public product launch remains 1.0. No public deployments or unnecessary paid calls. Commit useful increments and maintain documentation alongside implementation.

## Implementation choices

- SwiftUI/AppKit selected over GPUI: the current Mac has a working Swift toolchain; Rust/GPUI and full Xcode were not established. This is genuinely native, not an embedded website. GPUI has not been implemented.
- Native system sans-serif and serif typography with SF Symbols keep controls coherent with macOS. Monospace is confined to the ASCII artwork and technical text.
- SQLite C API avoids third-party runtime dependencies. Preserve the original relational migration; add native tables. Old web scaffold and HTML design studies remain historical, not runnable product claims.
- NSTextView supplies rich text, selection, undo and native keyboard editing; RTF plus plain-text serialization preserves portability. A dedicated block editor is deferred.
- Provider credentials belong in Keychain for this local desktop architecture, replacing the obsolete web server-only implementation detail. Private lore still leaves the machine only on explicit provider submission.
- The canonical snapshot remains independent from the mutable draft. Exact-version review is mandatory; the model has no approval tools.
- Actual native window captures replace browser screenshots because the shipping target is macOS. A 390-point capture checks compact layout; it is not an iOS or browser build.

Earlier Next.js/Drizzle and Markdown-only design choices were superseded by the owner's native complete-rebuild directive. They do not describe the current app.

## 2026-11-12 — latest owner direction (protected)

UI first: pause broader application feature development. Replace the light serif welcome composition with an infinite canvas, reference-matched modular navigation (power systems, universal history and related sections), customized guided chat, fluid interactions and no separate macOS title bar. The newly supplied three screenshots and Zeron composer are the current visual reference set. This supersedes the earlier light chat-home visual specification where they conflict; data ownership, explicit canon approval and privacy boundaries remain.

## 2026-11-12 — connected workspace refinement (owner-protected)

The owner accepted the graphite foundation and explicitly authorized integration into the real application. This supersedes the UI-study pause: independent persisted assistance mode, Conversation as assisted entry, compact canvas composer with resizable docked companion, actual source-backed records, curated Canvas separate from derived Graph, and shared Library/Timeline/Atlas. Empty boards remain empty. Templates and guided prompts are optional. No model call without deliberate submission; no implicit canon promotion.

## 2026-11-12 — product audit implementation choices

- **Titled window instead of borderless.** A borderless window had no close, minimise, zoom or full screen and was invisible to native automation. A titled window with full-size content and a transparent title bar keeps the integrated 56-point header the owner asked for while restoring standard behaviour. The traffic lights are re-centred by resizing the title-bar container; AppKit resets them on appearance changes, so `StudioWindow.update()` reapplies the layout. Alternative considered: an empty unified toolbar, rejected because toolbar hit-testing blocks controls drawn beneath it.
- **Archive, never delete.** Records, conversations, boards and events gain an `archived` flag (migration 0004). Archived rows keep IDs, history, canon snapshots and links, are excluded from lists, search, relationships and the graph, and remain in export. This satisfies the reversible-removal contract without a trash table.
- **Records open over the current workspace.** `openRecord` no longer changes the destination, so Back returns to Canvas, Graph or wherever the creator was.
- **One bar per workspace.** The global header merged into `WorkspaceBar` to remove a second 56-point row and the duplicated world name. World identity stays persistent in navigation; the assistance switch stays persistent in every bar.
- **Superseded UI removed.** The earlier studies (RootView, CanvasDesign and others) were deleted rather than kept compiling; git history is the archive. This reverses the earlier "retained source history" note in ARCHITECTURE.
- **Graph layout is derived.** Fruchterman–Reingold inside a frame shaped like the workspace, seeded deterministically from sorted record IDs. Positions are not stored; dragging a node is a temporary adjustment.
- **Verification without taking over the machine.** Captures render the window frame while the app stays behind other windows. Pointer checks post events to the app's own window; because SwiftUI gestures only respond in the key window of the active app, that runner comes forward briefly and reports skipped checks if focus is taken.

## 2026-11-12 — safe AI depth

- **Proposals ride in the answer text.** The provider adapter streams plain text, so a change set is one fenced JSON block at the end of the answer rather than provider-specific tool calls. This keeps the adapter boundary thin and lets any text model participate. The cost is that a model may ignore or malform the block; malformed blocks are dropped and the prose still shows.
- **Per-change review, drafts only.** Accepting a proposed change calls the same draft operations a creator uses, with origin `ai-proposed`. There is deliberately no "accept as canon"; canon keeps its own exact-revision review.
- **Confirmation by ID.** `resolveChange` requires the proposal's ID, as `promote` requires the record's, so the approval boundary is a property of the store API and is covered by a test.
- **Context is recorded, not just sent.** Every answer stores the records it was given and why, satisfying traceability and making the privacy disclosure concrete.
- **Mentions are tokens over Markdown.** The stored message keeps `[Title](synthesis://record/id)`; the composer shows a token. Old drafts and transcripts need no migration.

## 2026-11-13 — owner direction: subscription harness by default (protected)

The owner directed that the assistant should not depend on an API key: the default is a local harness signed in with a subscription, with the API still allowed. Implemented as Claude Code (preferred when installed, because it can run with no tools at all) or Codex, with the OpenAI key as a third option. The harness is spawned per message and locked down as described in AI_SETUP. Alternatives considered: the Claude Agent SDK (adds a Node runtime to a native app for no gain over the CLI already installed) and a long-lived harness session (keeps context between turns but makes cancellation, isolation and the Manual-mode guarantee harder to prove). Both harnesses were verified live once; see AI_SETUP.

## 2026-11-13 — owner direction: Canvas built on Excalidraw (protected)

The owner directed that the canvas be built on Excalidraw's open-source engine and customised as needed. This supersedes the earlier "no WebView" implementation note for the Canvas workspace only; the rest of the application stays native SwiftUI/AppKit.

- Uses the published `@excalidraw/excalidraw` package (MIT) rather than a source fork: the component API covers cards, arrows, theming, menus and link handling, and upgrades stay simple. A fork remains possible if deeper engine changes are needed.
- The bundle is built with Vite and committed, so building the app needs no Node toolchain. Fonts are bundled; the CJK handwriting font is omitted for size.
- Record cards and relationships are ordinary Excalidraw elements tagged with `customData`, so every engine feature (drawing, shapes, text, images, frames, grouping, alignment, undo) applies to them.
- Removing a relationship arrow hides it on that board; it does not archive the relationship. This mirrors "removing a card keeps the record".
- Trade-off accepted: a web view cannot be captured by view caching and is not repainted by WebKit while re-attached in an occluded window, which limits background screenshots (see HANDOFF).

## 2026-11-13 — custom canvas presentation and quiet verification

Owner direction: retain Claude’s active worktree, customize the open-source engine to Synthesis world rules, use the supplied node-workspace reference, add GPT imagery, and keep verification in the background. The published Excalidraw engine remains responsible for scene editing/history. A pointer-transparent DOM presentation follows its actual geometry, rather than duplicating the scene model or replacing the native app. Ports request native relationship review; they never silently establish canon. PNG fidelity is an explicit remaining trade-off.

Bundled GPT-generated map/portrait illustrations are optional local choices. Existing lore and images are not overwritten. Runtime image-provider integration is deferred rather than simulated. Background tests use temporary bundles, fresh databases and a rejecting model transport; foreground self-test is not run while the owner works. No protected instruction was weakened, and AGENTS.md was not changed.

## 2026-11-13 — primary checkout and GitHub main (owner-protected)

The owner explicitly selected the reviewed implementation as the main product, requested removal of other worktrees, authorized pushing to GitHub and requested the app be started for review. The canonical source/launch location is now `/Users/desenyon/Developer/synthesis` on `main`, with `dist/Synthesis.app`. GitHub's default branch is `main`. The merge retains both branch histories but takes the reviewed source tree; it does not resurrect the superseded SwiftFlow frontend. Unfinished rules files are checkpointed rather than discarded. Recovery archives and user data stay local; no release or deployment is requested.

## 2026-11-15 — subscription-only and connected workspace (owner protected)

The owner explicitly removed the direct API option, superseding the earlier optional API decision. Claude Code and Codex subscription sign-in are the only model paths. The application may validate proposed domain actions and apply them only after UI review; the harness receives no general application or shell write authority. Canon approval remains separate.

The owner also requested removal of unused code. `legacy/web`, `docs/design`, the obsolete API adapter, placeholder file and old pixel-art components were retired. Source history remains in Git; local ignored legacy files/previews were moved to `~/Library/Application Support/Synthesis/Development Archives/retired-scaffolds-20261115/`. No user world data was removed.

Use upstream Lucide 1.73.0 consistently for authored UI; retain the Excalidraw package as the OSS editing engine and build the Synthesis domain bridge/presentation around its public APIs. This avoids a large engine fork while adding real Library, relationship, board and agent actions. The new graphite sidebar and shared theme follow the available owner reference/design brief. No new attachment arrived with the latest request, so exact parity with it is not a verified claim.

## 2026-11-15 — Owner's next studio pass (supersedes the previous icon/color choice)

- Owner direction: pure black, restrained glass navigation, a better font and a new OSS icon family. Use Phosphor and locally bundled Inter consistently. Keep system window controls native. Capitalize Synthesis and place collapse after the brand.
- Portable worlds use a versioned JSON-based `.synthesis` snapshot, imported as an independent copy. Keep SQLite as the working database. Automatic filesystem synchronization and file associations are not implemented.
- Keep canon distinctions in review and editing, while removing decorative draft/provider badges from browsing surfaces. Shared assistance lives with content and remains optional.
- Systems is the navigation umbrella for factions/clans/sects. Older Factions categories remain intact and are included in that lens.
- Chronology branches/periods are saved organizational structures, not automatic alternate-canon simulations. Requested image generation remains a separate, explicit-use future integration; text harness calls disable Codex image generation.

## 2026-11-15 — searchable Settings and scoped preferences

The owner requested simpler Settings plus more functional controls. Use five searchable sections in the native workspace instead of the long nested form. Compact windows use a section menu. Onboarding shares the provider control; selecting a provider starts neither authentication checks nor generation. Chat setup links open Assistant settings, removing the obsolete Settings modal.

Store validated device presentation preferences separately from per-world creation defaults. World defaults travel in `.synthesis` v4; v1–v3 imports remain supported, and device/provider preferences remain excluded. Writing size applies to unformatted content and the Body style, preserving stored rich formatting. Identity fields save together transactionally. No canon, provider-safety, C2 or C3 boundary changes.

## 2026-11-16 — native creative components over ordinary lore

The owner requested intelligent, customizable UI across creative workspaces. Use a validated native component vocabulary (Notes, Facts, Checklist, Progression) whose content is ordinary revisioned lore. An entity component is also an entity section. The assistant proposes descriptors and content through the existing approval pipeline; it never supplies executable UI or changes canon autonomously. This keeps Manual mode complete and content searchable/exportable. Workspace-level components are shared across that world's destination; per-board positioning and a larger component vocabulary remain later work. Existing specialized Canvas, Graph, Timeline and Atlas data models remain authoritative.

## 2026-11-16 — Mechanics history and safe agent revisions

Rule history is an additive, world-scoped snapshot table, written in the same transaction as a rule mutation. Restoring history makes a draft; accepting canon remains a separate exact-snapshot action. The proposal pipeline validates rule IDs independently from lore IDs and compares the staged rule before-state before applying changes. Scenarios preserve creator-authored conclusions; model proposals can describe a hypothetical situation and expectation only. Native typed components continue to provide customization without executing model-produced UI code.

## 2026-11-16 — owner-directed sidebar refinement (protected)

The owner requested a 304–320pt graphite sidebar with restrained native translucency, monochrome navigation and the existing world artwork as its identity. Implemented at 312pt, retaining Inter, Phosphor, all Studio actions and the native titled window. This updates the sidebar portion of the earlier black/opaque presentation decision; the workspace palette and C2's broader theme proposal remain unchanged.

Use an explicitly themed `NSVisualEffectView` with an 88% opaque tint, never adaptive Liquid Glass. Reduce Transparency/Increase Contrast use the opaque token. One scrolling middle prevents history from competing with fixed top and bottom controls. Shared 150ms interaction states honor Reduce Motion. No new navigation model, world data or database migration is introduced. [Design and verification contract](SIDEBAR.md).

## 2026-11-16 — narrower sidebar and development releases (owner protected)

The owner's follow-up requested horizontal compaction without another redesign and explicitly authorized the first development release. The accepted sidebar composition is retained at 284pt; 0.0.1 is published as a prerelease. This supersedes the earlier width target and no-release restriction. The public product launch remains 1.0. Subsequent fixes on main do not silently replace the published tag or binary.


## 2026-11-16 — follow-up development checkpoint

Keep v0.0.1 and its binary intact. Package the verified interaction follow-up as v0.0.2 under the owner's authorization for development prereleases. Native contextual chat floats above secondary workspaces while the Canvas companion remains docked (or takes over a compact workspace). Edits to existing chronology/map/relationship structures go through typed proposals and captured metadata, not executable model UI or unrestricted tools. No new canon permissions, provider credentials or automatic model calls are introduced.
