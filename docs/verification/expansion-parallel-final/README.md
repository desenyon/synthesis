# Mac acceptance sweep

The baseline capture used `3b0693a`. It rendered the exact 69-state handoff manifest at 1440×900, 1024×768, and 720×800. The manifest check verified 207 main frames, 18 Quick Capture panels, the Canvas export, all output dimensions, and the completion marker. The root and three independent reviewers inspected every size. [Capture log](capture.log) · [1440×900](overview-1440x900.jpg) · [1024×768](overview-1024x768.jpg) · [720×800](overview-720x800.jpg)

`./scripts/check.sh` passed strict Swift format lint, 390 tests in 96 suites, and the optimized isolated build. `./scripts/verify-session.sh` wrote and reopened a disposable database in two separate executions. Canvas passed 20 Node tests, TypeScript and the offline bundle build. The sweep ran 59 native and WebKit assertions including saved viewport, correlated flush, exact image reveal, typed reference placement and the outgoing-board drop guard. [Session processes](session-4.log)

The first sweep stopped at `session-canvas` after 58 main frames and six panels. The fixture probed before its reveal animation finished. The fixed fixture selects without animation, compares the live and committed viewport, and checks the same values on a fresh engine. It also asserts the full newest draft. A focused run rendered 15 main frames and confirmed the fresh Canvas engine and Focus from Properties at all three sizes. [Focused log](focused.log)

| Requirement | Observed evidence |
| --- | --- |
| #36 | The native proposal fixture displays three faction drafts and three dependent relationships. The stand-in request exercises stage and explicit approval. Review actions keep the results as drafts. |
| #43 | Five branch states per size show lineage, exact source, Manual reading and the Canvas companion. Prefix copying and archive/source recovery have native and core tests. The branch excerpt regression now preserves spacing and readable prose. |
| #44 | Seven recipe states per size show new, active, archived, applied and Manual results. Native and core tests exercise reuse, local persistence, frozen scope and Undo. |
| #67 | `relationship-outgoing` and `relationship-incoming` display opposite readings of the same stored edge. The native test opens the other endpoint and confirms no reverse edge was written. |
| #70 | `entity-names` and `entity-name-edit` show dated names, aliases and unknown bounds. Storage and editor tests cover search, archival, portable IDs, caret and Undo, and the unchanged accepted title. |
| #98 | The focused captures start at Properties, show the native writer under Focus and restore Properties. A mounted test exercises Properties, Mechanics and Sections and checks that editor selection survives. |
| #133 | The relationship form accepts qualitative strength and the inspector displays it. The scoped native/core relationship tests verify the metadata round trip. |

The compact review found a clipped Canvas header and toolbar, displaced Quick Capture window controls, and two missing property glyphs. The medium review found that the fixture could overwrite the seeded editor selection with an already-mounted editor handle. Follow-up evidence tracks these corrections. The sweep uses a disposable database and a blocked model transport. Physical drag routing, global hotkey delivery, focus return, VoiceOver and live subscription behavior require separate authorization.

## Follow-up captures

The next isolated build passed strict lint, 404 tests in 102 suites, and both session processes. The recapture rendered 114 main frames and 18 Quick Capture panels across the three window sizes. It passed 59 Canvas assertions and nine exact native editor selection assertions. Independent reviewers inspected all three sizes. [Follow-up log](follow-up.log)

- #33 editor selection, the newest draft and Canvas viewport and selection are confirmed. The compact Drawing, Arrange and zoom controls now fit inside the window, and all six Quick Capture state panels center the title-bar controls.
- #47 verifies request pins and capped history ordering with the actual stand-in payload in World and Attachments scopes. Exclusions retain priority. Large histories contribute a bounded slice.
- #62 and #65 show distinct edit and history glyphs, the template editor and the typed creation flow. Tests cover local schema revisions and independent templates. Existing typed profile gaps remain tracked separately under #61, #63, #64 and #66.
- #86 visibly distinguishes Portrait, Location artwork and Banner at every size. #146 and #147 show real root and child map navigation, including an empty parent with a nested local map.
- The initial Graph preview overlapped some cards, the offscreen relationship history sheet clipped, the selected chronology lost controls at 720×800, and the regional fixture retained the previous empty child map. See the corrected captures below.
- Canvas Add now opens a local source picker for events, proposals and Atlas images. In all modes, selection re-resolves the source and confirms the board save. Drag routing and Quick Capture hotkey/focus behavior remain pending separately authorized foreground evidence.

## Timeline, Facts, and atomic Review

`./scripts/check.sh` passed strict Swift format lint and 422 native tests in 106 suites, then built and signed the optimized isolated bundle. Both independent session processes passed. Three independent reviewers inspected each of the 16 corrected frames per size. The manifest and PNG headers confirm all 48 main frames at the requested window sizes and 2× backing scale. [Capture log](timeline-facts.log) · [Session log](session-10.log) · [1440×900](timeline-facts-1440x900.jpg) · [1024×768](timeline-facts-1024x768.jpg) · [720×800](timeline-facts-720x800.jpg)

- #129, #136, #152 and #200. Graph fits the different one- and two-degree sets. Relationship history fits with closing controls and entries visible. Atlas shows actual selected polygon geometry with Open record. The compact selected hierarchy shows event counts, the full range in its group header, and row controls.
- #68 and #69. The baseline relationship forms show the editable metadata and explicit meanings. Current native tests also verify branch proposals retain those fields and correctly rebind typed evidence when reviewed or exported.
- #184 and #186. The date axis, event-date editor and named calendar form render at all three sizes. Calendar and archive tests preserve explicit elapsed dates and literal legacy dates. Detailed hourly zoom and multiple calendar systems are separate open items.
- #74. The Facts tab presents the saved and canon states separately, with explicit approval of the reviewed revision. Native tests check exact immutable document revision evidence. Reasoning over facts and direct event evidence remain open under #72 and #73.
- #269. Review keeps the pending batch visible and offers an explicit draft action. Native core and UI tests roll back the batch and preserve all pending decisions when a later draft write fails.
- #48. Stand-in payload tests verify rich-text world references redact excluded source labels in both working and accepted excerpts. The requirement remains in progress.

The first focused run stopped after a world switch let a stale mounted inspector query its previous record against the new world. The fixed inspector scopes reads to the record's original world. The capture now checks for errors after layout, and the corrected frames completed without the alert. Capture and tests used disposable data and the background runner.
