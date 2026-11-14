# Refinement evidence — 2026-11-13

Source: Claude's active `swift-falcon` worktree. Actual native window and embedded WebKit engine; no HTML preview or provider call. The broad sweep (`broad-capture.log`) has 78 captures reviewed across 20 contact pages, retained locally in `test-results/refinement-final`. The final sweep (`capture.log`) has 20 captures and 15 engine/native-save checks. Its five contact pages are included here and were inspected. A final shutdown regression run (`shutdown-audit.log`) passes 17 checks, adding withheld-save-acknowledgement and recovery cases.

`canvas`, `light`, `companion`, `manual`, `sheet-artwork` and the five contact pages come from the final sweep. `atlas` comes from the broad sweep. Sheet content in the final background run is rendered inline from the real SwiftUI view; native modal presentation is explicitly unverified. The app rejects activation requests during this run, ignores pointer events and asserts it remains inactive/non-key. Physical mouse, trackpad, VoiceOver, animation FPS and live streaming were not tested.

- `native-tests.log`: 51 tests in six suites pass, including the preserved unfinished rules work.
- `release-build.log`: separate `dist/Synthesis-review.app` optimized build.
- `full-lint-existing-errors.log`: eight existing strict-format errors in the uncommitted core rules work; full check.sh is not a pass.
- TypeScript typecheck/bundle build and six Node tests passed; scoped Swift UI/app/test lint passed.
- Capture-startup sentinel check passed, refusing absent/existing database paths without modifying the sentinel.

Earlier focused runs exposed layering, duplicate text, image size limits, mobile chrome, picker width and modal activation bugs. Those diagnostic captures remain locally in `test-results`. This evidence does not assert all features or exact reference parity are complete; see `../REFINEMENT_AUDIT.md`.
