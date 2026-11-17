# Shared composer refinement — 2026-11-17

Native SwiftUI/AppKit captures from the canonical checkout, using an isolated Aster fixture database. No personal lore or live provider calls. This is unreleased main after 0.0.3.

## Checks observed

- `./scripts/check.sh`: strict Swift format lint, **175 tests in 42 suites**, optimized build and ad-hoc app signing passed; see `check.log`.
- `ComposerLayoutTests.growingComposerRevealsFirstLineWithoutMovingCaret` failed before the scroll-offset correction (`layout-red.log`) and passes in `check.log`. It also checks that genuinely overflowing drafts retain their offset and that text/caret survive.
- **40 final states** (20 at each size) inspected in `contact-1440x900.jpg` and `contact-1024x768.jpg`. `before-after.jpg` compares the attached composer at the same 1440×900 size against the prior main build.
- README composer, context and Conversation images refreshed from these final captures.

## Capture commands

```sh
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 \
SYNTHESIS_CAPTURE_STATES=conversation-home,composer-attached,light-composer-attached,composer-context,light-composer-context,composer-browser,composer-overflow,composer-expanded,conversation,conversation-loading,manual-conversation,companion,library-companion,graph-selected,timeline-companion,editor,composer-companion,light-composer-companion,composer-command-return,composer-unavailable \
./scripts/verify-ui.sh docs/verification/composer-polish

# Six focused recaptures after the final wrapping correction:
SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 \
SYNTHESIS_CAPTURE_STATES=composer-companion,light-composer-companion,composer-overflow \
./scripts/verify-ui.sh /tmp/synthesis-composer-wrap-final
```

Those six final images replaced their earlier counterparts before the contact sheets were regenerated. `capture.log` records the full pass; `wrap-capture.log` records the focused pass. Contact sheets are therefore a composite of the final inspected states, not one invocation. Source PNGs were pruned after README copies and inspection.

## Visual iteration and limits

`initial-edge-states/` preserves the first contact sheets that exposed a clipped multiline first line and a third companion attachment outside the allocated row. The native editor now remeasures after layout and resets stale offsets only when all text fits; attachment rows measure their real available width and height, showing two rows before scrolling. Final captures show the first line and wrapped third reference correctly in both sizes/themes.

This pass checks rendering and native/core regressions. It does not verify foreground typing, native popover interaction, animation timing, VoiceOver, or a live subscription response. Context/browser fixture panels render the real panel content inline without activating a popover. No Canvas source changed; its separate Node suite was not rerun.
