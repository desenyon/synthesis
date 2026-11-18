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
