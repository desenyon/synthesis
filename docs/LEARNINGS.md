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

Owner explicitly authorized connecting the accepted visual foundation to the real model and removing the UI-study restriction. AGENTS initial-experience paragraph was replaced with that direction; canon/privacy boundaries were unchanged. Evidence: the twelve-priority targeted refinement request. Validation: optimized native build, 18 tests including four new UI-model regressions, and ongoing native inspection. Rollback: revert only this operational paragraph if the owner changes direction.

Independent review found delayed viewport saves could overwrite newer controllers and companion conversation switching cleared the canvas save guard. Explicit flush now cancels deferred saves; companion chat navigation preserves its workspace/save callback. Tests cover both scenarios, plus mode independence and board layout/undo. Compact composer provider disclosure was restored; Manual no longer changes destination.
