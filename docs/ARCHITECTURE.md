# Architecture

## Current parallel additions — expansion #33–36, #43–44, #61–70

`WorkspaceSession` stores per-world device presentation separately from portable lore: document tabs, editor positions, view framing/selections, filters, inspectors and conversation read positions. It checkpoints the latest composer draft in the same transaction. Restoring filters stale addresses, preserves unreadable preferences and cannot enable AI or replay a request. Native editor Undo remains in-memory. The independent `verify-session.sh` runner exercises two actual executable processes against disposable data.

Quick capture uses an ordinary nonactivating `NSPanel`, a launch-local Carbon shortcut and a world-scoped scratch draft. Record creation, retry receipt and scratch removal share one transaction. No provider, main-window route or canon state is changed. Automated instances do not register the shortcut.

Migration 0016 adds optional entity types, inheritance, typed profile values, templates, accepted property snapshots and revision histories. Derived FTS is rebuilt from validated data. Formulas use a bounded arithmetic parser, never executable code. Structured canon requires a frozen review token; later schema/default edits cannot rewrite the accepted snapshot. Migration 0017 adds conversation lineage, copied-message origins and optimistic prompt recipes. Branches copy a selected message prefix with new IDs; proposal ownership and approvals stay with the original conversation.

Portable archives are v12 and JSON exports schema 15. Nested references are remapped and validated before import commits; device sessions, scratch drafts and provider credentials are excluded. [Entity schema details](ENTITY_SCHEMAS.md), [conversation tools](CONVERSATION_TOOLS.md), [sessions](SESSION_RESTORE.md) and [quick capture](QUICK_CAPTURE.md) describe the new boundaries. The ledger tracks verification status.

Workspace transfers use process-local typed addresses. A recipient claims one gesture and validates its world, source, target and Canvas generation before writing. Opening a reference resolves its current source. Canvas correlates each explicit save acknowledgment with its request. Rich-text links remain portable in working, accepted and historical snapshots.

Related AI operations can stage together. A model-defined key for a newly proposed record resolves to the app's generated change ID within that batch. Existing records use stored IDs. Review displays unmet prerequisites, and the store checks that each dependency was explicitly accepted before allowing its dependent draft. Canon approval remains separate.

Migration 0018 adds typed and versioned metadata to the existing directed relationship. Both endpoints query the same edge, preserving direction. Draft metadata writes save the prior values and activity in the same transaction. Evidence addresses are restricted to the same world and remap independently of creator-authored date text. [Relationship guide](RELATIONSHIPS.md)

Migration 0019 adds separate name periods and their revisions for each entity. The Library search index includes active dated names without changing the ordinary alias array. Applying a historical name to the working title uses the existing draft revision path. Imports remap identity columns while preserving the creator's literal names and date labels.

Primary source: `main` in `/Users/desenyon/Developer/synthesis`; development bundle: `dist/Synthesis.app`. The former `swift-falcon` worktree is retired.

## Application shell

`SynthesisApp` hosts `ConnectedRoot` (Shell.swift) in `StudioWindow`, a titled window with full-size content and a transparent title bar. The window keeps native controls, resizing, full screen and frame autosave; `layoutTrafficLights()` centres the buttons in the 56-point header and is reapplied from `update()`.

`ConnectedRoot` lays out the navigation (`Sidebar.swift`), the active workspace and global overlays: the command palette, toasts and the error alert. Navigation, assistance mode and the open record are independent pieces of `Studio` state. A record opens over the current workspace (`selectedRecord`); its breadcrumb returns there. `DocumentTabs.swift` keeps per-world device-local open/pinned/recent record addresses. Closing the active tab selects a remaining tab, or returns to the workspace. `EditorHandle` retains each open native text view and independent undo manager; navigation flushes autosave first. External content reloads clear obsolete native undo. Tab addresses are resolved against current world records and filtered for archive/ownership, never exported as lore.

## Design system

`Theme.swift` holds colour/state/stroke tokens for graphite, OLED and light, shared `Metric`, `Space`, `Elevation`, motion values and vocabulary. `Typography.swift` supplies semantic `TextRole` roles over bundled Inter; controls, page headings, card titles, captions and section labels use the shared scale. `Components.swift` holds the pieces every screen uses: `WorkspaceBar` (context, actions, the persistent `ModeSwitch`, search), `BarTitle`, `BarAction`, `QuietButton`, `IconButton`, `PlainMenu`, `FilterChip`, `SearchField`, `FormField`, `StateBadge`, `CategoryTile`, `EmptyState`, `SheetScaffold`, `ZoomControls` and the floating-panel surface. `WorkspaceBar` uses `ViewThatFits` to collapse labelled actions to icons when space is short.

The sidebar uses `SidebarPalette` and `SidebarMetric` in Theme, with `SidebarControlStyle` and `NavigationGlass` in Components. Its default 284pt expanded surface (adjustable 240–360pt; 72pt rail) has fixed identity/actions and utilities around one scrolling navigation/history region. Native vibrancy has an explicit appearance and an opaque accessibility fallback. Studio's destinations, category lenses and conversation actions are unchanged. `SidebarConfiguration.swift` persists section order, hidden categories and pinned collections under `navigation:<worldID>` on this Mac. Updates read the latest preference before merging; unreadable or future-version data remains untouched until explicit reset. `SidebarCustomization.swift` shares the native sheet and segmented controls, with separate Arrangement, Categories and Favorites pages. Hidden collections remain searchable and available in Library; category aliases deduplicate navigation without rewriting lore. `Favorites.swift` resolves stored favorite record IDs from live world records. IDs survive archive/restore, while display uses fresh titles and opening uses the existing save/archive guards. Favorites and document-tab pins have separate lifetimes; neither changes lore, canon or portable exports.

`FrostedSurface` applies an in-window `NSVisualEffectView` only to floating tools, inspectors, menus and composers. Explicit theme appearance and a lightly tinted fill keep text readable; Reduce Transparency and Increase Contrast use an opaque surface. Menus inherit the active Theme, including OLED, from the root environment. Canvas only receives a theme bridge update when the resolved palette changes.

## Workspaces

- `Conversation.swift`: `ConversationStudio` (full width or companion) and `ChatRow`. `Composer.swift` supplies the shared full/compact `UnifiedComposer`; `AssistantContextPanel.swift` provides attachment browsing and local request inspection. The composer owns keystrokes locally, measures its own height and debounces draft persistence. `Markdown.swift` parses answers into blocks with a pure, tested parser.
- `CuratedCanvas.swift` with `CanvasSession` (CanvasHost.swift): the board is the Excalidraw editor, built from `CanvasWeb/` into `CanvasBundle` and loaded in a `WKWebView` from the application bundle through the `synthesis-canvas://` scheme. A content security policy and the navigation delegate forbid every other origin; nothing is fetched from the network. A JSON bridge loads scenes, syncs record cards and relationship arrows, and receives changes, link activations and connection requests. Board rows store `{format:"excalidraw", scene, hiddenRelations, legacy?}`; earlier `CanvasDocument` layouts are converted on first open and kept. One session lives for the whole run so late edits still save; quitting waits for a flush. Canonical relationships cannot be relabelled from the canvas. Details: HANDOFF.md.
- `Graph.swift`: `GraphLayout` uses bundled Dagre 3.1.3 through JavaScriptCore, with native cards and port routing. `GraphDetail` changes visible bounds/content by zoom without moving Dagre centres; routing shares those bounds. Only visible detailed nodes fetch artwork, decoded off the main actor into a bounded revision cache. The derived layout is not stored. Copying to canvas creates a separate board referencing the same records.
- `Library.swift`, `Editor.swift`: list with full-text search and archive; editor with `RecordInspector` and `TextDiff`-based canon review. `Timeline.swift`, `Atlas.swift`: sourced events and map markers.
- `CommandPalette.swift`, `Sheets.swift`: ⌘K and new-record, new-world, rename and first-run sheets.
- `Settings.swift`, `SettingsCatalog.swift`: one searchable Settings workspace, compact section navigation, shared onboarding/provider connection control and explicit world-detail saves. Settings entry points in chat navigate here; the old modal is removed.
- `CaptureFixtures.swift`, `SelfTest.swift`: authored fixtures and the interaction self-test. Both refuse to run outside the isolated runner (`SYNTHESIS_CAPTURE_DIR`).

## Removal

Migration 0004 adds `archived` to records, conversations, boards and events. Archived rows keep their IDs, revisions, canon snapshots and links; they are excluded from lists, full-text search, relationships and linked-record queries, and included in export. `Studio.archive` shows an Undo toast. Relationships keep their earlier audited archive and restore.

## Runtime

Swift package, macOS 14+, SwiftUI presentation with AppKit window/menu integration and NSTextView rich editing. Only Canvas embeds a bundled offline WKWebView; the other workspaces are native. No Next.js runtime, Rust dependency or hosted service. The installed command-line Swift toolchain builds against macOS 26.5 SDK; scripts avoid the default 27 SDK's unavailable SwiftUI macro plugin. Development bundle is ad-hoc signed.

- `SynthesisCore`: SQLite C driver, migrations, domain operations, full-text retrieval, agent cancellation, subscription harness transport.
- `SynthesisUI`: observable Studio state, design system, shell and connected workspaces.
- `SynthesisApp`: NSApplication lifecycle, native menu shortcuts, window and screenshot harness.
- `Tests/SynthesisCoreTests`: disk persistence, world isolation, canon/revision boundary, reversible archive and injected transport tests.
- `Tests/SynthesisUITests`: Studio navigation and archive, board controller, Markdown, diff, connector and graph layout.

SQLite lives at `~/Library/Application Support/Synthesis/synthesis.sqlite`; `SYNTHESIS_DATABASE_PATH` overrides it for isolated tests. Foreign keys, WAL and migrations are enabled. Original v1 tables remain; additive v2 tables hold conversations/messages, rich documents, preferences, native revision snapshots and boards. The unused TypeScript scaffold and HTML previews were removed from the checkout by owner instruction; Git history retains them.

Records carry world ID, kind, title, plain text, category, state, origin and version. RTF is stored separately so plain text remains recoverable. Accepted canon is a snapshot independent from working content. Saves use version checks; navigation and quit flush editor changes, and failures keep the active draft open. History records exact versions. Migration 0011 journals unsaved editor text for explicit Restore/Discard after a crash.

All domain operations validate local world ownership and membership. FTS5 is world-scoped. Entity relationships and chronology reference actual records. Boards store versionable JSON. Exports include records, conversations, revisions, relations, events and boards. PostgreSQL would require a new driver and search implementation; this is not a drop-in migration.

## AI boundary

`ModelTransport` is the provider boundary. `ProviderRouter` sends each request to the provider selected at that moment: `ClaudeCodeTransport` or `CodexTransport` (HarnessTransport.swift), which run a local agent harness the creator has signed in to with a subscription, only. Direct API transport and credentials UI are removed. Subscription status is checked before each generation. Each harness call is a fresh process in an empty scratch folder with the prompt on standard input; Claude Code runs with no tools, MCP servers, slash commands or user settings, Codex in a read-only sandbox with shell_tool disabled and without user config, rules, apps or plugins. Inherited API-key variables are stripped. Cancelling the task terminates the process. Synthesis holds no harness credentials. Sending explicitly discloses who receives the message; there is no background generation. Manual mode is persisted and checked inside AgentEngine before transport invocation. Cancellation invalidates a generation ID and prevents late answers from being saved. UI request tokens prevent stale completions from replacing a newer request.

`WorkspaceStore.assistantContext` (AssistantContext.swift) builds both local previews and submitted context. Explicit attachments and workspace selections precede ranked retrieval; World scope expands those anchors through entity sections, full-text matches, graph/link neighbours and recent work. Attachments-only scope does not expand into unrelated records. Record exclusions also filter rules, relations, events, components and board placements in the workspace index. Restricted scope omits previous conversation messages. Full record excerpt limits are 8/16/32; this is not a token or cost budget. Maps and boards contribute linked lore and bounded metadata, not image bytes. Each selected source carries its reason, retained in `message_context` with the answer. This remains single-shot retrieval, not an autonomous tool loop; the complete historical workspace-index snapshot is not yet persisted.

`assistant-context:<worldID>` preferences store intent, scope, attachments, exclusions and selection/history choices locally. They are omitted from portable world exports. Archived attachments are pruned on reload; exclusions survive archive/Undo. Invalid saved preferences restore Explore with attachments-only scope and selection/history off. UI and core validate current world ownership before requests. `Studio.commitComposer` and pending draft flushes compare the shared draft with the value the view last observed, preventing a disappearing composer or stale debounce from overwriting a newer draft.

In Propose, a model answer may end with one fenced `synthesis-proposal` JSON block. `ProposalParser` removes it from the transcript; `stageProposal` validates every change against the selected world (unknown IDs, cross-world IDs and unknown actions are dropped) and stores it pending in `proposals`. Explore discards such blocks in the core and explains that nothing was staged. `resolveChange` applies or dismisses one change and requires the proposal's own ID as confirmation, mirroring `promote`; `AgentEngine` has no path to it. Accepted changes call ordinary draft operations with origin `ai-proposed`, inside a transaction. Nothing in this path sets canon. Current composer verification uses injected transports and a capture transport that refuses every model request; earlier live checks remain separately recorded in STATE.

## Data notes

Page references use the world-scoped `links` table; incoming references are queried independently of semantic relationships. Tags and aliases participate in FTS and versioned snapshots. Canvas and atlas serialize typed Codable documents into world-scoped boards; images are bounded base64 inside the local board. World covers are scoped preferences. Exports (schema version 9) include records, conversations, revisions, relationships and their history, events, boards, links and everything archived.

## Canvas presentation and isolation — refinement audit

`StudioOverlay.tsx` draws the user-facing card surfaces, artwork, ports and toolbars over Excalidraw. Card bodies are pointer-transparent; engine elements retain geometry, selection, groups, gestures and undo. Only explicit actions/ports intercept input. Render refreshes are coalesced through `requestAnimationFrame`; offscreen cards are culled and artwork/neighbor lookup is indexed per refresh. This is not a second scene store. `sceneRules.ts` holds tested transforms, rotated hit testing, group ownership and relation/session rules.

Card rectangles/text are transparent engine elements during display; DOM surfaces represent them. Export restores their opacity for engine PNG rendering, which preserves content but differs from live card styling. Optional artwork remains real engine image files. `cards.ts` owns record synchronization and typed relation arrows. Innermost Excalidraw group IDs identify a card, so an outer user-created group cannot merge record content.

Every load carries a unique session ID echoed on bridge messages. Native and web checks reject stale generations; pending save/analyze timers are cancelled on load. Board switching flushes before replacement and stops on a failed acknowledgement. A cancellable timeout belongs to the current flush only. `Studio.flushCanvas()` returns success; both window close and application termination honor it instead of exiting after an unconfirmed save. Scene reset precedes file restoration. Old boards retain their legacy payload; no schema replacement is required.

`Artwork.swift` exposes optional bundled GPT illustrations, with provenance in `Assets/GENERATED_ARTWORK.md`. Atlas replacement is an explicit local action with Undo. `browserImageBase64` bounds inputs and converts TIFF/HEIC into actual PNG for WebKit. `RecordPicker.swift` supplies searchable selections without arbitrary 60/80-record menu limits.

The capture runner uses a fresh explicit database, a transport that always rejects model requests and accessory activation with non-key/non-main, mouse-transparent capture windows below normal window level. `SynthesisApplication` ignores activation requests only for background captures. Background sheet content renders inline through `SheetPresentation.swift`; real AppKit sheet presentation is retained in normal use and the explicit foreground runner. `verify-ui.sh` packages into a temporary bundle, leaving the user's app alone. Native compositing combines the window snapshot with the actual WebKit snapshot. `window.synthesis.audit()` exercises the engine in this isolated fixture; it does not claim physical event or animation performance coverage.

## Mechanics and rule history

Migration 0006 stores world-scoped rules and scenarios. The entity Mechanics tab provides rule cards, kind filters, editing, reversible removal, scenarios, structural considerations and explicit rule canon review. Migration 0010 adds transactional rule snapshots before and after changes; history can restore an earlier wording as a draft without replacing accepted canon. Rule edits and approvals can require an exact expected snapshot to reject stale UI or agent changes. Existing rules acquire history on their first change. Rules and scenarios enter bounded assistant context; Markdown exports rule wording, JSON schema 9 and portable worlds retain complete history. Scenarios are creator-authored hypothetical exercises, not deterministic simulations. [Usage](MECHANICS.md).

## Connected action and presentation changes — 2026-11-15

`WorkspaceActions.swift` is the domain boundary for board placements and Atlas markers. It preserves existing JSON scene fields, files and hidden relationships; moves only the innermost record group; and rejects foreign or archived records. `Studio.resolve` flushes editor/Canvas before approval, applies validated proposals, reloads world data and reloads the active board after placement. Graph and Atlas observe `worldRevision`, so relationship-only and marker-only changes refresh without requiring a text edit.

The assistant receives `workspaceContext` in addition to retrieved lore: bounded record identities, relationship tuples, chronology, boards and placements, including total counts indicating truncation. No image bytes are sent. The source list is persisted; the index snapshot itself still needs a trace table. The action contract now includes board creation, spatial placements, record links and draft rules. Accepting revisions checks `baseVersion`; ambiguous record titles must be resolved by ID. Canon never changes through this contract.

`StudioIcon.swift` maps semantic identifiers to the bundled upstream Phosphor regular font. Canvas uses `@phosphor-icons/react`; alias mappings and licenses are committed. Inter is bundled in native OTF and web font assets. `Typography.swift` centralizes native fonts and the translucent sidebar material with a reduce-transparency fallback. Dark uses a pure-black workspace; light remains supported.

Canvas still uses the published OSS engine rather than a fork. Synthesis owns the card presentation, relationship routes, source actions and drawing-style panel; the engine owns scene operations, pointer gestures, selection, history and serialization. `Save as idea` explicitly converts board text into a Library capture and linked card. Shared relationship inspection uses native domain edits. Mechanics supplies the structured rule/scenario UI for any entity category. A spatial technique tree, simulation engine and branch merging remain separate work.

## Portable worlds and chronology — 2026-11-15

`WorldArchive.swift` exports `.synthesis` format version 9: allowlisted world tables plus cover/composer and validated world-default preferences. Import accepts v1–v9, validates table/column names and foreign-world references, assigns fresh UUIDs, remaps embedded references and writes in one transaction. It does not import device/provider settings or overwrite existing worlds. 200 MB / 100,000-row input bounds. JSON export schema 12 includes chronology (including archived lanes), technique prerequisites, artwork revisions and activity history.

Migration 0007 adds nested chronology lanes (branch/period) and event placements. Events retain actual source records and free-form dates. A grouping is not a canon branch: no speculative merge or inheritance is implied. Reviewed agent actions can create a branch/period and assign new events to existing lanes or earlier branch/period changes in the same proposal. Dependencies resolve only after creator acceptance. Events may create a draft source atomically when none is supplied. Request context includes lane IDs and memberships.

The shared companion resizes non-Canvas workspaces and includes the open record in retrieval. Canvas keeps its own movable composer/dock. The native shell must remain transparent over the mounted WKWebView. Engine-composited captures cannot detect native occlusion; live on-screen inspection verified this correction.

World-scoped FTS now returns complete matched records in one query rather than fetching each result separately. Library and quick-open cache query results across hover/selection redraws.

Markdown export now shares `Portability.recordMarkdown` between world files and `exportRecordMarkdown`. Single-record exports embed sections and local anchors. `MarkdownText` decodes native RTF with AppKit and maps editor headings, emphasis, underline and links; plain Markdown is preserved verbatim, and mismatched/invalid RTF falls back to the stored text. `.synthesis` remains the lossless archive for exact rich formatting.

`Preferences.swift` stores validated device presentation preferences separately from per-world creation defaults. Missing or malformed device values fall back safely; world identity updates are transactional. Device/provider settings are excluded from portable archives.

## Connected presentation — 2026-11-16

Conversation, the docked companion and the compact workspace input share `UnifiedComposer`. `PlainMenu` presents app-themed native popovers and `MenuSection` replaces nested system submenus. The shell animates workspace and companion changes; reduced motion cancels those transactions.

`AgentActivity` carries observed native retrieval, request and proposal-staging events to `AIActivityView` (Kokonut UI adaptation). Request/world/conversation guards reject late events. No timed fake tool playback is shipped. Sources remain persisted separately in `message_context`; activity timing is currently live-only. See [AI_COMPONENTS](AI_COMPONENTS.md).

`GraphLayout` runs pinned Dagre 3.1.3 inside a fresh JavaScriptCore context with fixed JSON-safe inputs. The compatibility shim supplies the structured clone used for Dagre’s numeric/string layout values. The graph renderer stays SwiftUI; `GraphRoute` clips cubic paths to rectangular card ports and routes overlapping cards outside their content. A grid is only an emergency fallback; tests distinguish it from the directed engine. Canvas uses the same OSS engine for explicit undoable auto-arrangement, while Excalidraw retains gestures/history and saved placement.

`exportBoard.ts` combines the engine scene with the Synthesis card presentation (Inter text, category, state, relationship count and local artwork). It never mutates the live scene, caps output at 4096 pixels per edge, and only decodes data-image artwork. Export callbacks are session-guarded. Background Canvas audits save the real PNG for visual inspection without a native save dialog.

## Creative components — 2026-11-16

Migration 0009 adds a closed presentation descriptor (notes/facts/checklist/progression; workspace scope or entity parent) pointing to an ordinary lore record. Entity components use existing section membership. Content is revisioned/searchable/citable and retains the normal canon boundary; component removal archives presentation only. A version-checked checklist edit cannot replace accepted canon. No model code is executed. `create_component` stages through the existing proposal pipeline and produces a draft only after scoped approval. `.synthesis` v6 / JSON schema 9 include descriptors and rule history; archives before v5 import with no components, and archives before v6 import with no rule history. [Usage and limits](CREATIVE_COMPONENTS.md).

The reviewed action vocabulary includes `revise_rule` with its captured before-state and `add_scenario` with an expectation, never an agent-written verdict. Acceptance checks the rule ID separately from lore record IDs and validates its active owner. Agent approval cannot promote a rule to canon. Form choices use the same themed `ChoiceField`/`PlainMenu` as the rest of the application.

## Named Atlas maps — 2026-11-16

Atlas retains the existing board format with optional `placeID` and `parentMapID`. `AtlasMaps.swift` validates world membership, bounded ancestry, marker IDs and normalized finite coordinates. Saves require the expected prior Board content/name in a transaction. UI Undo captures the original world/map and expected replacement, so switching maps cannot redirect Undo or overwrite newer edits. Parent removal is blocked while active children exist. The provider sees active map metadata and can stage `create_map`; image selection stays explicit and local. [Usage and boundaries](ATLAS.md).

## 0.0.1 interaction and privacy fixes

`SpatialViewport` is the common focal-point zoom transform for Graph and Atlas, with workspace-specific limits. Buttons use the viewport centre; gestures use the pointer. Invalid gesture coordinates are ignored. Atlas retains the decoded map image between loads/replacements instead of decoding base64 on every pan/zoom render. Graph details float without changing the coordinate viewport. Canvas relationship arrows/text are locked; overlay label hit targets open the native RelationEditor, including explicit board hiding. Free arrows stay ordinary Excalidraw drawings until the creator converts them. Sidebar and shared hover modifiers reset transient state on navigation/disappearance.

AgentEngine receives an explicit workspace snapshot from Studio.send before any route change. HarnessProcess inherits only runtime/authentication variables; Codex disables memory/import/skill discovery and project documents in addition to the previous tool restrictions. Studio.resolve publishes worldRevision after accepted changes and selects the map affected by create_map/place_marker. Timeline displays persisted lane hierarchy; reviewed change references resolve using accepted result IDs, not guessed UUIDs.


## 0.0.2 — request recovery and workspace revisions

Studio snapshots the actual workspace, selected Graph/Atlas/Canvas records, open editor, board/map and selected chronology lane at submission. Navigation is local and never submits a request. The core validates every ID against the selected world. Interrupted provider prose is saved as an incomplete assistant message with its source context; partial change sets are not staged. A later continuation includes that incomplete prose with an explicit label. Unsent prompts and new retry drafts survive cancellation/failure. A native clip-view observer stops automatic transcript scrolling while the creator reads earlier messages.

`WorkspaceRevisions.swift` adds `revise_event`, `revise_lane`, `revise_map` and `revise_relationship`. `ProposedChange.workspaceBefore` is optional Codable metadata, so existing saved proposals remain readable without a migration. Acceptance compares the world-scoped current snapshot in the existing SQLite transaction, then applies through domain writers. Map edits merge metadata into the current map without replacing artwork/markers. Timeline edits preserve source records; lane reparenting rejects cycles. Review renders changed fields before approval. Unrecognized or invalid members of a partially valid proposal are counted explicitly.

Studio approval resets chronology filtering to All history, selects affected maps and publishes `worldRevision`. Review now observes that revision too, so relation-only changes refresh consistency results. Contextual companions float over Graph/Atlas/Library/editor and retain width; Canvas retains docking/takeover behavior. Opening the floating companion preserves the underlying viewport size.

Canvas load commits the engine viewport before sending `loaded`. Stored relationship elements stay locked, share one route builder with converted arrows, and place labels on the route midpoint. Canvas and Graph add exterior curves for close parallel nodes and basic intervening-card detours; this is not a general obstacle-routing guarantee for dense boards. Graph reuses computed routes within a render. The offline CSP and bundled engine boundary remain unchanged.

`HarnessSelection` is a lock-protected, per-Studio runtime cache captured by the provider router. SQLite remains the persistence authority. Production provider/model selection no longer reads or writes shared `UserDefaults`, so isolated capture/test instances cannot redirect another running app’s requests. Canvas initial fitting is committed before its load acknowledgement, just like saved viewport restoration.


## 2026-11-16 additions

- Migration 0011 `editor_journal`: device-local recovery copy of unsaved editor text, cleared on save, never exported.
- Migration 0012 `world_branches`, `branch_origins`, `branch_items`: what-if branches are independent world copies made through the archive import with its ID map; `proposeBranchMerge` stages their clean changes as one `branch-merge` proposal in the original, reviewed per change. Conflicts, archives and title/category-only edits are previewed, never sent.
- Migration 0013 `rule_prerequisites`: technique/progression requirement edges within one system, loop-checked, archived on removal, included in `.synthesis` v7 and JSON schema 10. Mechanics derives the tree with the bundled Dagre layout (node size and spacing are parameters).
- `WorldChecks` adds contradictory relationships, timeline order against comparable same-era dates, and tag spelling variants with a reversible merge.
- `.synthesis` is an exported document type (`dev.desenyon.synthesis.world`); Finder opens confirm before importing a copy.

## Entity artwork and empty profiles

Migration 0014 adds world-scoped `record_artwork` revisions with an active-image uniqueness constraint. `RecordArtwork.swift` validates decoded PNG/JPEG bytes, dimensions, size, entity ownership and expected current image before replacement. Removal/replacement archives; stale Undo is rejected. Artwork is an optional visual reference, separate from written canon, and never enters model prompts implicitly. Portable v8 snapshots include all revisions, remap owners and reject invalid images/owners atomically; JSON schema 11 includes archived images. Markdown embeds the active image as a data URI; image export collects active entity artwork alongside maps, boards and world covers.

`EntityProfileStart` offers optional category-specific writing prompts, artwork, real relationship links and sourced history when an entity's body is empty. Start writing enters the existing rich editor without inserting prompt text. Already-active editors remain active if all prose is deleted, preserving Undo. Studio profile-to-Graph/Timeline actions flush unsaved text and reject foreign-world records; new events use the originating entity as source.

### Shared interaction feedback

`Interaction.swift` owns native transient hover lifecycle. `ConnectedRoot` supplies a world/workspace/object scope; scope changes, disabled controls, disappearance and app/window deactivation clear hover. Motion tokens in `Theme.swift` provide restrained feedback, panel and workspace transitions, with accessibility Reduce Motion respected. No interaction state is persisted as lore.

### Contextual inspection

`ObjectInspection.swift` builds read-only, active-world projections for records, events, chronology lanes, maps, canvas boards, relationships, conversations, proposals and world identity. `ObjectInspector` follows current selection or an explicitly inspected reference without navigating the main view. Visibility and preferred width persist; the default 300pt dock (260–480pt) becomes a dismissible overlay below the toolbar in narrow windows. Native frosted backing prevents the persistent WKWebView from drawing through the floating inspector. The editor retains its existing editable inspector, also available in Mechanics. Inspection never submits a model request or accepts a proposal.

### Navigation history

`NavigationLocation` stores only world-scoped addresses; `NavigationEntry` supplies display labels. `withNavigation` coalesces nested operations into one bounded visit, while failed editor saves and repeated addresses leave history intact. Replay validates targets and resolves current records; archived targets are skipped, database failures are surfaced. The common WorkspaceBar supplies Back/Forward; native menu shortcuts and context menus expose history. Editor breadcrumbs show the immediate connected-record trail. The stack is session-local; complete restart restoration is separately tracked at #33. Optional `NavigationContext` snapshots entity tabs, Settings/search, Library query/filter/order, Review tab/focus and inspected source. Subpage helpers use the same history/save boundary. Same-mounted-editor replay retains its save callback; optional missing/foreign inspected sources clear without reviving them.

## Saved workspace layouts

`WorkspaceLayouts.swift` stores versioned per-world, device-local arrangements in preferences. Layouts carry navigation addresses, panel state, density, reading width and entity tab; never text, canon, theme or model permissions. Restore validates targets and flushes writing before using the shared navigation path, then saves related preferences in one SQLite transaction. Rename, explicit Update, archive/restore and guarded Undo preserve earlier arrangements. Native View → Workspace Layouts (⌥⌘L), Settings and quick-open share one manager. Full application-session restoration is separate (#33).

## Welcome dashboard

`Dashboard.swift` combines current Studio records/proposals with a bounded world-scoped `recentWorldActivity` query across saved records, maps/boards, relationships, chronology and proposal decisions. Activity shows the latest state per object, not a full append-only audit log. Navigation resolves actual source objects through existing save guards. The optional Dashboard destination has no model calls and can be selected as startup in Settings. Existing ⌘1–9 destinations retain their shortcuts.

Project outlines are ordinary entity records with category `Projects`: draft/canon rules, revisions, archive, sections, relationships and portable exports already apply. This is the project entry point for #13; it does not claim the later multi-book/script project engine (#313).

## Resizable panels — expansion #19

`PanelSizing.swift` centralizes panel bounds and preference updates. `PanelDividerView` supplies AppKit pointer tracking, keyboard actions and an accessibility splitter inside a fixed nine-point hit region. Dragging changes published dimensions; release/focus loss commits once. Window constraints affect presentation only. The editor docks only when at least 480pt remains for writing. Saved layouts add optional sidebar/inspector dimensions for backward compatibility; companion width retains its existing key. `PanelSizingAudit` verifies rendered frames and native accessibility actions without activating the test window.

## Shared entity selection — expansion #20

`EntitySurface` in Interaction.swift applies Theme selection/hover tokens to graph cards, timeline events, inspected Library rows and Atlas shapes/labels without affecting layout. Native hover uses the existing focus/context lifecycle. Canvas articles mirror actual Excalidraw selection; pointer-transparent bodies retain engine drag/history, while keyboard events update the grouped engine elements. CSS uses the display palette for cards and inverse-filter palette for engine handles. Selection alone never writes lore or approves proposals.

## Universal command palette

`CommandCatalog.swift` builds ⌘K results from the actual workspace, category and Settings catalogs, selected-world records and FTS results, named boards/maps, conversations and recent object activity. `CommandPalette.swift` owns read refresh/error state, adaptive result-list geometry and keyboard selection. Activity refreshes on world revision rather than every keystroke. Actions resolve through Studio navigation/save guards; stale or foreign sources cannot recreate archived data. Recent activity is the latest saved state per object, not a complete audit log. Search and command navigation work in Manual mode without model calls.

## Structured search

`LoreSearchQuery.swift` parses bounded free text, quoted phrases and typed filters. `LoreSearch.swift` composes parameterized, world-scoped queries over existing records/FTS/relationships, with explicit archive scope. Database registers a Unicode case/diacritic-insensitive collation for exact creator-authored names, categories, tags and aliases. FTS candidates are materialized once before joining records; the existing scale test caught repeated virtual-table scans without that boundary. Library and ⌘K share this core path; structured queries bypass name-only/capture fallbacks. Invalid filters display locally. Agent retrieval retains its separate retrieval query; this change neither widens agent context nor adds a provider call.

## Committed world activity — expansion #25

Migration 0015 appends source-scoped history through SQLite triggers in the same transaction as the mutation. `synthesis_uuid()` gives each entry a portable stable identifier. `WorldChangeHistory` provides world validation, source availability, parameterized search/filters and stable date/rowid pagination. `BoardActivity` compares parsed board content while excluding viewport and engine revision bookkeeping; the complete original content is still saved. Message streaming, provider/device preferences and no-op updates do not log.

`ActivityHistoryMigration` reconstructs preserved native/original record revisions, relationship history and rule snapshots, with labeled saved-state baselines elsewhere. Migration is atomic and runs once. v9 archives include history; import suppresses synthetic trigger entries, remaps/validates every source, reconstructs older files and appends one import entry. Dashboard, ⌘K and View menu open `WorldActivitySheet`; current sources resolve through existing navigation/save guards. History is independent of fictional chronology and cannot promote canon.


### Split workspace

`SplitWorkspace.swift` composes the existing primary workspace and a second `EditorScreen` over one world model. `EditorPlacement` routes save registration, focus-sensitive document commands and independent inspector state. Both native editor handles remain record-owned; a record moves between panes instead of mounting twice. `flushEditor` checks both callbacks before navigation. The per-world secondary address, device-wide width and optional saved-layout fields are local preferences; no new lore schema is introduced. Narrow windows stack panes and short editors scroll their writing content. One shared composer draws below the split and includes both sources under the existing privacy filters.

Canvas remains mounted once in the shell. Its visibility and overlay insets account for the split. The bundled viewport helper supplies precise fit bounds to Excalidraw to avoid its 10-percent floor rounding in short panes; the engine still owns scrolling, animation and persistence. Short Canvas panes arrange drawing tools horizontally.

### Local record drag (expansion #27)

`RecordDragAddress` carries only a version and stable world/record IDs through an own-process NSItemProvider type declared in the app bundle. Search, Favorites and Library use one source modifier. Transient native drop surfaces resolve current records, validate the source and captured destination, and invoke existing guarded editor navigation. Canvas converts native viewport coordinates in the offline engine, moves or creates the grouped record card without changing lore, uses engine Undo and confirms native persistence. Its board-generation token protects delayed WebKit delivery. No new schema, model authority or export format is introduced.

### Atlas view sessions (expansion #28)

`AtlasViewSession` outlives the SwiftUI Atlas view. Versioned `atlas-view:<world>:<map>` preferences store image-relative framing, layer visibility and selection; `atlas-last-map:<world>` remembers the active map. Save/navigation boundaries persist changes, with no per-input database writes or lore revisions. The session validates world ownership and reconciles archived/removed selections against fresh map data. Invalid preferences are preserved before replacement. Optional `NavigationLocation.atlasView` snapshots make history and existing saved layouts restore the exact visit; older layouts remain readable.

`RecordCreation.swift` owns guarded creation commands and world-bound link drafts. `RecordLinkSheet.swift` is shared by the native menu, palette and Graph; references use existing `links`, semantic entity pairs use transactional `relationships`. Submission resolves live endpoints and does not modify canon. Native menu key equivalents are verified without posting OS-wide events or activating the app.

Startup choices share `StartupWorkspace` between core validation and Settings; existing persisted strings stay compatible. The `withNavigation` boundary remembers completed direct routes as well as sidebar navigation, while history replay persists its restored destination. Opening a home never calls the provider; Manual preserves the Library fallback for Conversation. Startup captures construct a new Studio and mount a fresh ConnectedRoot from persisted preferences. Full view-session restoration is tracked separately in #33.
