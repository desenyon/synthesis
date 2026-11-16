# Synthesis audit — what is broken, and a fix prompt for each

Audit date: 2026-11-15, `main` after commit `3efed30` plus the entity-sections work.

## How this was produced

- Built the real app and rendered all 47 capture states at 1440×900 and 1024×768 with `./scripts/verify-ui.sh` (94 screenshots, isolated database, sample world "Aster" and an empty world).
- Read the UI source for the shell, sidebar, components, editor, sections, Library and Conversation, and grepped the rest for each defect below.
- `./scripts/check.sh` passed: strict lint, 78 tests in 17 suites, optimized build.

**Not exercised:** a live model reply, real pointer work (dragging, drawing on Canvas, resizing the companion), native sheets as modal windows (captures draw sheet content inline), and open/save dialogs. Items marked *capture-only* were seen in background captures and need one look in the running window before and after the fix.

## How to use this file

Fix in the order listed. Each item has a prompt you can paste into a fresh coding session on its own. To run everything, use the master prompt at the end.

Every prompt assumes this preamble (it is included in the master prompt; add it yourself when running one item alone):

> Work in `/Users/desenyon/Developer/synthesis` on `main`. Read `AGENTS.md` and `docs/AUDIT.md` first. Keep explicit canon approval, archive-not-delete, and the titled `StudioWindow`. Style only through `Theme.swift` and `Components.swift`. After the change run `./scripts/check.sh`, then `./scripts/verify-ui.sh <dir>` for the affected states, build contact sheets with `scripts/contact-sheets.py <dir>`, and look at them before claiming the result. Tick the item in `docs/AUDIT.md`, log it in `docs/PROGRESS.md`, commit and push.

## Summary

| # | Severity | Problem |
| --- | --- | --- |
| A1 | Critical | Sidebar renders in the opposite theme: white with washed-out labels in dark mode, black in light mode |
| A2 | Critical | Canvas top bar is see-through: white bar in dark mode, black in light, board title unreadable |
| B1 | High | Section records flood the Library, sidebar counts and conversation suggestions |
| B2 | High | Opening any character/place lands on the Sections tab and hides the writing |
| B3 | High | Timeline cannot record an event in a world with no records |
| B4 | High | Canvas composer covers cards after Fit |
| B5 | Medium | Canvas cards print the category twice, with two different names for it |
| B6 | Medium | "Factions" and "Systems" are used for the same thing on different screens |
| B7 | Medium | Editor "Export as Markdown" drops formatting and sections, and names untitled files `.md` |
| B8 | Medium | Worlds dashboard ignores cover images and shows the same canned description on every world |
| B9 | Medium | "Add rule" appears on every entity, including characters; the rule text box has no label |
| B10 | Low | Review sidebar badge says 2 while the tabs total 5 |
| B11 | Low | Vendor name in product copy ("GPT illustration") |
| C1 | High | No shared content column: lists are centred while bars and chips sit left, on Library, Review, Timeline |
| C2 | High | Dark theme has almost no depth: black on near-black, large dead areas |
| C3 | Medium | The floating composer is on every screen, costs about 100px and covers content |
| C4 | Medium | At 1024 wide with the companion open, the editor breadcrumb collapses to "Li… / N" |
| C5 | Medium | Settings order and controls are confusing; theme is a lone icon |
| C6 | Low | Onboarding sheet carries settings noise |
| C7 | Low | Compact sidebar clips the World list and hides Conversations |
| D1 | Medium | `empty-sections` capture is wrong, so the empty Sections state has never been checked |
| D2 | Medium | Captures cannot show native sheets; sheet over Canvas renders transparent |

---

## A. Theme and chrome (fix first — this is most of "looks bad")

### A1. Sidebar renders in the opposite theme — Critical, capture-only

**Seen:** in most dark captures (conversation-home, editor, graph, timeline, review, sections, settings, worlds, all sheets) the sidebar is a white panel beside a black workspace, with the brand, world name and nav labels almost invisible. In the `light` Canvas capture the sidebar is black with dark text. `sheet-artwork` shows doubled, ghosted sidebar text. Other dark captures (canvas, atlas, library, conversation) render correctly, so the result is unstable rather than simply inverted.

**Cause:** `NavigationGlass` in `Sources/SynthesisUI/Typography.swift:43` uses `.glassEffect(.regular.tint(...))` on macOS 26+. Liquid Glass picks light or dark from what is behind it, not from `Studio.dark`. The window never sets `NSWindow.appearance`; only SwiftUI's `.preferredColorScheme` is set (`Shell.swift:85`), and `main.swift` only updates `window.backgroundColor`.

**Fix:**
1. In `NavigationGlass`, remove the `glassEffect` and `.ultraThinMaterial` branches. Fill with `theme.sidebar` and keep the 1px trailing hairline. If translucency is still wanted, use an `NSVisualEffectView` wrapper with `material = .sidebar`, `blendingMode = .behindWindow`, `state = .active`, and `appearance` set explicitly from the theme, with a `theme.sidebar.opacity(0.85)` overlay.
2. In `Sources/SynthesisApp/main.swift`, set `window.appearance = NSAppearance(named: studio.dark ? .darkAqua : .aqua)` wherever `window.backgroundColor` is set (launch, the theme observer near line 149, the capture loop), so traffic lights, menus and sheets follow the app theme.
3. Add a UI test or capture assertion: sample a sidebar pixel in a dark capture and a light capture and check its luminance is on the right side.

**Prompt:**
> Fix AUDIT A1. In `Sources/SynthesisUI/Typography.swift` replace the `glassEffect` and `ultraThinMaterial` branches of `NavigationGlass` with an opaque `theme.sidebar` fill plus the existing 1px trailing hairline (or an `NSVisualEffectView` with an explicit `appearance` taken from the theme). In `Sources/SynthesisApp/main.swift` set `window.appearance` to `.darkAqua`/`.aqua` from `studio.dark` everywhere `window.backgroundColor` is assigned. Capture `conversation-home,editor,graph,timeline,light,light-editor,sheet-artwork` at 1440x900 and confirm the sidebar matches the theme in every one, with readable labels. Then toggle the theme three times in the running app and confirm the sidebar follows each time.

- [x] done — opaque theme surface, explicit native appearance; see verification/audit-A1.

### A2. Canvas top bar is transparent — Critical, capture-only

**Seen:** `empty-canvas`, `collapsed` and the 1024 `companion` capture show a white bar across the top of a dark Canvas with the board name nearly invisible. The `light` capture shows a black bar on a light Canvas.

**Cause:** `Shell.swift:42-45` clears the background of the whole Canvas workspace so the web view underneath shows through. That includes the `WorkspaceBar`, which should be opaque. Only the board area that reports `CanvasFrameKey` (`CuratedCanvas.swift:323`) needs to be clear.

**Fix:** in `CuratedCanvas.swift`, give the `WorkspaceBar` (and any native strip that is not the board) `.background(studio.t.background)`. Leave only the `Color.clear` area that publishes `CanvasFrameKey` transparent. Check the web view's own page background too: `CanvasWeb/src/canvas.css` sets the page transparent and `.synthesis-board` to `#000`/`#f5f6f7`; make sure `setTheme` runs before first paint so there is no flash of the other theme.

**Prompt:**
> Fix AUDIT A2. In `Sources/SynthesisUI/CuratedCanvas.swift` give the Canvas `WorkspaceBar` an opaque `studio.t.background` so only the board area that publishes `CanvasFrameKey` stays clear. Do not change the clear workspace background in `Shell.swift` for the board itself. Confirm the engine receives the theme before first paint. Capture `canvas,empty-canvas,collapsed,companion,light` at both sizes and confirm the bar matches the theme and the board title is readable.

- [ ] live verification pending — implemented; ten background captures inspected. macOS capture fails with SCStreamErrorDomain -3812. See verification/audit-A2.

---

## B. Behaviour and data

### B1. Section records flood the Library and counts — High, confirmed in code

**Seen:** the sample world has 2 characters, but the sidebar says "Characters 5" and Library lists "Unanswered questions", "A borrowed craft", "What she is searching for" as top-level Characters. Conversation's "Bring something from your world" offers three sections of the same character first.

**Cause:** sections are real `lore` records that copy the parent's category (`RecordSections.swift:50`), and `Studio.records` returns every record. Nothing marks or filters section children.

**Fix:**
1. Core: add `WorkspaceStore.sectionMemberships(worldID:) -> [String: String]` (child record ID → parent ID, active memberships only).
2. `Studio`: load it in `reload()` as `sectionParents`; add `var topLevelRecords` that excludes those IDs.
3. Use `topLevelRecords` for sidebar category counts (`Shell.swift:212`), Library default list and chip counts, and Conversation home suggestions (`Conversation.swift:186`).
4. Library: add a "Sections" filter chip that shows them, and in `RecordRow` show "Section of <parent>" in the category column. Search, the command palette, `@` mentions and retrieval keep including sections.
5. Test: a world with one character and three sections reports a Characters count of 1.

**Prompt:**
> Fix AUDIT B1. Add `sectionMemberships(worldID:)` to `Sources/SynthesisCore/RecordSections.swift` returning active child-ID → parent-ID pairs. Load it in `Studio.reload()` and add `topLevelRecords`. Use it for sidebar category counts, the Library default list and chip counts, and Conversation home suggestions. Add a Library "Sections" filter and show "Section of <parent title>" on section rows. Keep sections in search, palette, mentions and retrieval. Add a core test and a UI test for the count. Capture `library,conversation-home,sections`.

- [x] done — see verification/audit-B1.

### B2. Entities open on the Sections tab — High, confirmed in code

**Seen:** `EditorScreen` starts with `sectionsVisible = true` (`Editor.swift:67`), so opening a character shows section cards (or an empty prompt) instead of its writing. The tab is labelled "Overview" but the Sections page repeats the title and a 4-line excerpt above the cards, which duplicates Overview.

**Fix:** default to Overview. Remember the last tab per record for the session in `Studio` (a `[String: Bool]`). On the Sections page remove the repeated title/excerpt block and keep the "Sections · n" header and cards. Show the section count on the tab chip.

**Prompt:**
> Fix AUDIT B2. In `Sources/SynthesisUI/Editor.swift` default `sectionsVisible` to false and remember the chosen tab per record ID in `Studio` for the session. Remove the capture-hint special case that forces Overview. In `RecordSections.swift` drop the repeated parent title and body excerpt at the top of `RecordSectionsPage`. Pass the section count to the "Sections" `FilterChip`. Update capture fixtures so `sections*` states select the Sections tab explicitly. Capture `editor,sections,light-sections`.

- [x] done — see verification/audit-B2.

### B3. Timeline needs a record before an event — High, seen in `empty-timeline`

**Seen:** in an empty world the primary "Event" button is disabled and the empty state says "Create a document or entity first". This breaks "creative flow first": a creator cannot jot down a date.

**Cause:** the event sheet requires a source record (`Timeline.swift:180` falls back to the first record).

**Fix:** check the `events` schema. If `source_id` is nullable, allow "No source yet" in the sheet and render such events with a "No source" chip. If it is NOT NULL, do not weaken the constraint; add "Write a new document for this event" in the sheet, which creates a draft lore record titled after the event in the same transaction and uses it as the source. Enable the bar button either way and change the empty-state action to "New event".

**Prompt:**
> Fix AUDIT B3. Inspect the events table in `Sources/SynthesisCore/Migrations` and `Chronology.swift`. If the source column is nullable, let the event sheet in `Sources/SynthesisUI/Timeline.swift` save with no source and show a "No source" chip. Otherwise add a sheet option that creates a draft lore record named after the event and the event in one transaction. Enable the "Event" bar action in an empty world and change the empty state to "New event". Add a core test. Capture `empty-timeline,timeline`.

- [x] done — see verification/audit-B3.

### B4. Canvas composer covers cards — High, seen in `canvas`, `collapsed`

**Seen:** after Fit, the bottom of "The art of remembrance" card (its connections footer) sits under the floating composer.

**Fix:** when the collapsed composer is visible, pass a bottom inset (composer height + 24, about 120pt) to the engine's fit call so content is framed above it. Do the same for the top toolbar and right tool rail.

**Prompt:**
> Fix AUDIT B4. Find the fit call in `Sources/SynthesisUI/CanvasHost.swift` and its handler in `CanvasWeb/src/App.tsx`. Add padding parameters (top, right, bottom, left) and have native pass the collapsed composer's height plus 24pt at the bottom, 76pt top and 80pt right. Rebuild the bundle with `cd CanvasWeb && npm run typecheck && npm test && npm run build`. Capture `canvas,collapsed,manual` and confirm no card sits under the composer or toolbars.

- [x] done — see verification/audit-B4.

### B5. Canvas cards repeat the category — Medium, confirmed in code

**Seen:** a card reads "Factions … Entity" at the top and "3 connections … Systems" at the bottom; "Characters" appears top and bottom.

**Cause:** `CanvasWeb/src/StudioOverlay.tsx:108` prints the raw category in the kicker and line 111 prints a normalized category again in the footer.

**Fix:** kicker shows the normalized category once. Footer right shows the record state (Draft / Canon) using the existing `.record-state` style. Drop the "Entity/Record" word unless the record has no category.

**Prompt:**
> Fix AUDIT B5. In `CanvasWeb/src/StudioOverlay.tsx` show the category once in the card kicker, normalized with the same Factions→Systems rule, and replace the footer's category with the record state using `.record-state`. Mirror the wording in `CanvasWeb/src/cards.ts` so PNG export matches. Rebuild the bundle and capture `canvas,light`.

- [x] done — see verification/audit-B5.

### B6. "Factions" vs "Systems" — Medium, confirmed

**Seen:** the sidebar says Systems, Library and the editor category menu say Factions for the same record.

**Fix:** add `Vocabulary.displayCategory(_:)` in `Theme.swift` that maps stored "Factions" to "Systems" for display only (stored data untouched). Use it in `Library.swift:221`, the editor category label, the palette, mention list and Graph inspector.

**Prompt:**
> Fix AUDIT B6. Add `Vocabulary.displayCategory` in `Sources/SynthesisUI/Theme.swift` mapping the stored category "Factions" to "Systems" for display only. Apply it to every place a record's category string is shown (grep `record.category` in `Sources/SynthesisUI`). Do not rewrite stored categories. Capture `library,editor,graph-selected,palette`.

- [x] done — see verification/audit-B6.

### B7. Editor Markdown export is lossy — Medium, confirmed in code

**Cause:** `Editor.swift:375` writes `# title\n\nbody` from plain text and names the file `"\(title).md"`, which is `.md` for an untitled record and unsafe for titles with `/`.

**Fix:** reuse the record Markdown writer in `Portability.swift` (the one world export uses) so headings, tags, aliases and section links are included. Default the file name to a sanitized title or "Untitled".

**Prompt:**
> Fix AUDIT B7. Replace the body of `export()` in `Sources/SynthesisUI/Editor.swift` with a call into the per-record Markdown writer used by world export in `Sources/SynthesisCore/Portability.swift` (expose one public function if needed). Use the existing path sanitizer for the default file name and fall back to "Untitled". For an entity, append its sections. Add a core test for an untitled record and a title containing "/".

- [x] done — see verification/audit-B7.

### B8. Worlds dashboard is thin — Medium, seen in `worlds`

**Seen:** three small cards in a mostly empty page. Aster has a cover image but the card shows a generic globe. "My world" and "Halcyon" both say "An open world of possibilities.", a canned line (`Worlds.swift:107`) for a description that cannot be edited anywhere.

**Fix:** show the cover image as the card header when present. Replace the canned line with real facts: record count, conversation count, last updated. Add a description field to the world section of Settings and show it on the card when set. Mark the current world.

**Prompt:**
> Fix AUDIT B8. In `Sources/SynthesisUI/Worlds.swift` render each world's cover image as a 16:9 card header when it has one, show "N records · updated <relative>" instead of the canned description, show the real description when set, and mark the open world. Add a store query for per-world counts. Add an editable description to the "This world" group in `Sheets.swift` settings. Capture `worlds,settings` at both sizes.

- [x] done — see verification/audit-B8.

### B9. Rules on every entity — Medium, seen in `sheet-rule`

**Seen:** the inspector offers "Add rule" on the character Mira Vale; the sheet says "Rules of Mira Vale". The large rule text box has no label.

**Fix:** show the Rules group only for Power systems, Cosmology and Systems, or when the record already has rules. Label the text box "Rule" with placeholder text.

**Prompt:**
> Fix AUDIT B9. In the record inspector in `Sources/SynthesisUI/Editor.swift` show the Rules group only when the record's category is Power systems, Cosmology, Systems/Factions, or it already has rules. In `RecordRuleEditor` add a visible "Rule" label and an accessibility label to the text editor. Capture `sheet-rule,editor`.

- [x] done — see verification/audit-B9.

### B10. Review badge does not match the tabs — Low

**Seen:** sidebar badge 2; tabs show Proposals 1, Canon 1, Checks 3.

**Fix:** keep the badge as decisions waiting (proposals + canon) and add a tooltip "1 proposal · 1 canon review". Show Checks count in muted style so it does not read as part of the total.

**Prompt:**
> Fix AUDIT B10. In `Shell.swift` add a help tooltip to the Review row that breaks down `reviewCount`. In `Review.swift` render the Checks chip count in the muted style used for non-actionable counts.

- [x] done — see verification/audit-B10.

### B11. Vendor name in copy — Low

**Seen:** "Choose a GPT illustration…" (`Atlas.swift:65`), "GPT illustrations…" (`CuratedCanvas.swift:199`), "GPT-generated artwork" (`Artwork.swift:32`).

**Fix:** "Sample illustrations…" and "Bundled sample artwork, AI-generated. Choosing one does not establish canon."

**Prompt:**
> Fix AUDIT B11. Replace the three "GPT" strings in `Atlas.swift`, `CuratedCanvas.swift` and `Artwork.swift` with "Sample illustrations…" and "Bundled sample artwork, AI-generated. Choosing one does not establish canon." Capture `empty-atlas,sheet-artwork`.

- [x] done — see verification/audit-B11.

---

## C. Layout and visual design

### C1. No shared content column — High

**Seen:** Library rows start 480px in while the filter chips start at 372px. Review's intro and cards are centred while its chips are left. Timeline's "All history" menu sits at 476px, the cards at 928px and "New branch / New period" at the far right. Every screen picks its own width (1040, 840, 780, 720).

**Fix:** add one `ContentColumn` container to `Components.swift` (max width 880, 28pt side padding, leading-aligned inside a centred column) and a matching `ContentHeader` row. Use it for Library (chips and list), Review, Timeline (filter row and events), Sections, Settings and Worlds so chips, intro text and rows share one left edge.

**Prompt:**
> Fix AUDIT C1. Add `ContentColumn` (max width 880, horizontal padding 28, centred) to `Sources/SynthesisUI/Components.swift`. Put the filter-chip row and the list of `LibraryScreen` inside it; do the same for `ReviewScreen`, `TimelineScreen` (the "All history" menu, New branch/New period and the event list on one edge), `RecordSectionsPage`, Settings and `WorldsScreen`. Remove the per-screen `frame(maxWidth: 1040/840/780)` values. Capture `library,review,review-checks,timeline,sections,settings,worlds` at both sizes and check one shared left edge per screen.

- [x] done — see verification/audit-C1.

### C2. Dark theme has no depth — High, needs your call

**Seen:** background `#000000`, cards `#111111`, borders `#2A2A2A` at 60% opacity. Cards barely separate from the page, and Timeline, Review and Worlds are mostly empty black. The pure-black studio was your earlier direction, so this changes a recorded decision.

**Recommended fix:** keep it dark but lift it: background `#0B0B0D`, sidebar `#111113`, surface `#17171A`, secondary surface `#1F1F23`, border `#2E2E33` at full opacity. Keep text colours. Record the change in `docs/DECISIONS.md`.

**Prompt:**
> Fix AUDIT C2 (owner approved lifting the dark palette). In `Sources/SynthesisUI/Theme.swift` set dark `background` 0x0B0B0D, `sidebar` 0x111113, `surface` 0x17171A, `secondarySurface` 0x1F1F23, `border` 0x2E2E33 and dark `hairline` opacity 1.0. Mirror the values in `CanvasWeb/src/palette.ts` and `canvas.css`, rebuild the bundle, and record the decision in `docs/DECISIONS.md`. Capture every dark state and check card edges are visible against the page.

- [ ] done

### C3. The composer is everywhere — Medium, needs your call

**Seen:** a 620pt-wide composer plus the "Shares world context with your AI provider" line floats over Library, Graph, Timeline, Atlas, Review and every record. It costs about 100pt, cuts off the inspector's last group ("Links") and covers Canvas cards.

**Recommended fix:** outside Conversation and Canvas, collapse it to a 36pt "Ask about …" pill at the bottom right that expands on click or ⌘J. Show the disclosure line only while the field has focus.

**Prompt:**
> Fix AUDIT C3 (owner approved). In `Shell.swift` replace the always-open collapsed `UnifiedComposer` inset on Library, Graph, Timeline, Atlas, Review and records with a 36pt pill button at the bottom trailing corner that expands into the existing compact composer on click or ⌘J and collapses on Escape when empty. Show the provider disclosure only while expanded. Keep Manual mode hiding it. Update the toast offset. Capture `library,editor,graph,timeline,review`.

- [ ] done

### C4. Editor bar collapses at 1024 with the companion — Medium

**Seen:** `sections-companion` at 1024×768: the breadcrumb reads "Li… / N", the title is gone.

**Fix:** in compact bars show only the back chevron (no "Library" label), drop the "Saved" status text to an icon, and give the title the layout priority.

**Prompt:**
> Fix AUDIT C4. In the `bar` of `EditorScreen` (`Editor.swift`) read `barCompact`: when compact, show only the back chevron, hide the "/" and the status text (keep a small saved/unsaved dot with a tooltip), and give the title `layoutPriority(1)`. Capture `sections-companion,editor` at 1024x768 and confirm the record title is readable.

- [x] done — see verification/audit-C4.

### C5. Settings order and controls — Medium

**Seen:** under "This world", "Images / Export images" comes before the world's Name. Theme is a single sun icon with the word "Dark". Export is spread over two rows.

**Fix:** order as Name, Description, Cover image, Import, Export (World file, Markdown, JSON, Images in one row). Make Theme a two-segment Light/Dark control built like `ModeSwitch`.

**Prompt:**
> Fix AUDIT C5. In the settings content in `Sources/SynthesisUI/Sheets.swift` reorder "This world" to Name, Description, Cover image, Import, Export, with all four export buttons on the Export row. Replace the theme icon with a Light/Dark segmented control extracted from `ModeSwitch` into a reusable `SegmentedSwitch` in `Components.swift`. Capture `settings,sheet-settings` at both sizes.

- [x] done — see verification/audit-C5.

### C6. Onboarding noise — Low

**Seen:** the welcome sheet includes an unlabelled "Optional — every manual tool works without it" paragraph, the model field with its own Save button, and a note about image generation not being available.

**Fix:** three steps only: world name, AI Assisted or Manual, provider choice with "Check sign-in". Add an "Assistant" label above the provider paragraph. Move the model field and the image note to Settings.

**Prompt:**
> Fix AUDIT C6. In the onboarding sheet in `Sources/SynthesisUI/Sheets.swift` keep world name, assistance mode, appearance and provider choice with sign-in check. Add an "Assistant" label above the provider text. Remove the model field and the image-generation note from onboarding (they stay in Settings). Capture `onboarding` at both sizes.

- [x] done — see verification/audit-C6.

### C7. Compact sidebar clipping — Low

**Seen:** at 1024×768 the sidebar ends at "Power systems"; Cosmology and Conversations are below the fold with no scroll cue, and the footer divider is a heavy dark line.

**Fix:** add a soft fade at the bottom of the scroll area and use `hairline` at normal weight for the footer divider.

**Prompt:**
> Fix AUDIT C7. In `Sidebar` (`Shell.swift`) add a 16pt bottom fade mask to the scroll view when content overflows, and make the footer divider a full-width 1px `hairline`. Capture `conversation,library` at 1024x768.

- [ ] done

---

## D. Verification tooling

### D1. `empty-sections` capture is wrong — Medium, confirmed

**Seen:** the capture shows the empty Library of the empty world. `configureConnectedCapture` switches to the empty world for any state starting with `empty-`, where the record it looks for does not exist (`CaptureFixtures.swift:208`).

**Fix:** rename the state to `sections-empty` and select a sample entity without sections ("Oren Ashe") with the Sections tab open.

**Prompt:**
> Fix AUDIT D1. In `Sources/SynthesisUI/CaptureFixtures.swift` rename the `empty-sections` state to `sections-empty`, keep the sample world, select "Oren Ashe" and open the Sections tab. Update the state list in `Studio.captureStates`. Capture it and confirm the "Make room for the details" empty card is shown.

- [x] done — see verification/audit-D1.

### D2. Sheets are not verified as real sheets — Medium

**Seen:** every sheet capture logs "content inline; native modal presentation not exercised". Inline, the artwork picker over Canvas has no backing and its text overlaps the cards.

**Fix:** give the inline capture path an opaque `t.background` panel with the sheet's corner radius, border and shadow so captures match the real sheet. Add one `selftest-ui.sh` step that opens a real sheet and closes it with Escape.

**Prompt:**
> Fix AUDIT D2. In `Sources/SynthesisUI/SheetPresentation.swift` make the inline capture presentation draw the sheet on an opaque `t.background` rounded panel with hairline border and shadow over a scrim. Add a self-test step in `SelfTest.swift` that opens the New record sheet as a real modal and dismisses it with Escape. Capture all `sheet-*` states.

- [x] done — see verification/audit-D2.

---

## Master run prompt

> Work in `/Users/desenyon/Developer/synthesis` on `main`. Read `AGENTS.md`, `docs/STATE.md` and `docs/AUDIT.md`. Fix the unticked items in `docs/AUDIT.md` in this order: A1, A2, B1, B2, C1, B4, B5, B6, B3, B7, B8, B9, C4, C5, D1, D2, B10, B11, C6, C7. Skip C2 and C3 unless I say they are approved. For each item: follow its "Fix" steps exactly, keep explicit canon approval, archive-not-delete and the titled `StudioWindow`, style only through `Theme.swift` and `Components.swift`, and rebuild the Canvas bundle when `CanvasWeb/` changes. After each item run `./scripts/check.sh`, capture the states named in the item with `./scripts/verify-ui.sh <dir>`, build contact sheets with `uv run --with pillow python scripts/contact-sheets.py <dir>` and look at them. If the capture still shows the defect, keep working on that item; do not tick it. Tick the box, add a line to `docs/PROGRESS.md` with the checks you actually ran, commit one item per commit and push. For A1 and A2, also check the running window in both themes. Finish by updating `docs/STATE.md` and reporting which items are done, which are not, and why.
