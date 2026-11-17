# Expansion #10 — contextual inspectors

Optional right-hand inspection now works across Conversation, Canvas, Library, Graph, Timeline, Atlas, Review, Worlds and Settings. Real records, events, branches, boards, maps, relationships, conversations and proposals share world-scoped projections. Following references changes only the inspector. Opening a record is explicit; Manual mode needs no provider. Visibility persists, selection can be followed again, and the editor inspector also works in Mechanics.

Verification: `./scripts/check.sh` passed strict lint, **184 tests / 46 suites**, optimized build. Three focused tests cover actual connected properties, archived/foreign targets, unchanged drafts/navigation/canon, persisted visibility and Canvas/companion sizing.

Initial captures: `SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 SYNTHESIS_CAPTURE_STATES=inspector-library,light-inspector-library,manual-inspector-library,inspector-graph,inspector-canvas,inspector-atlas,light-inspector-atlas,inspector-event,inspector-lane,inspector-conversation,inspector-review,inspector-worlds,inspector-settings,inspector-empty,inspector-hidden,inspector-mechanics ./scripts/verify-ui.sh docs/verification/expansion-010`.

All **32** states inspected in contact-sheet row crops. Refined property-column width, native frosted backing (embedded Canvas showed through the first floating inspector), and the Mechanics fixture's actual inspector toggle. Then captured **8** final states with the same sizes and `SYNTHESIS_CAPTURE_STATES=inspector-canvas,inspector-empty,inspector-mechanics,light-inspector-library` into `refined/`; both final sheets inspected. Source PNGs pruned after sheets were built.

No foreground pointer/key events, animation-pacing claim, live model call or release. Captures use isolated sample data and do not interrupt the owner's app.
