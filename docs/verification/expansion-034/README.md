# Expansion #34 — Universal quick capture

Requirement: “A single shortcut opens a small window to record an idea without disrupting the current workflow.”

Status: implemented; final coordinated check passed 334 tests / 81 suites, strict lint and optimized build. Corrected native visual inspection remains pending. Do not mark Verified from this checkpoint.

## Implementation

- One native nonactivating, resizable panel reached through the registered Control–Option–Space hotkey, File menu and command palette.
- Current-world default and an independent universe picker; one persisted scratch draft per universe.
- Command–Return saves a normal idea. Escape/close keep the draft. Save failures preserve the text and target.
- Atomic record creation, retry receipt and scratch clearing; retries cannot duplicate an idea or erase a newer scratch draft.
- No canon promotion, model requests, navigation changes, Accessibility permission or additional helper process.
- Application termination flushes the outstanding scratch draft before allowing quit.

## Checks prepared

`QuickCaptureTests` covers disk reopen, world isolation, export exclusions, idea/canon state, idempotent retry, rollback when scratch clearing fails, newer-draft protection and invalid input.

`QuickCaptureModelTests` covers destination switching without main-workspace navigation, recovery, save/close failure, current-world refresh and native panel traits without activating the application or registering a hotkey.

Real capture states: `quick-capture-empty`, `quick-capture-writing`, `quick-capture-other-world`, `quick-capture-error`, `quick-capture-saved`, `light-quick-capture-writing`. The runner renders the actual offscreen native panel, checks that it is neither key nor main, and verifies real save results against its isolated database.

## Observed so far

- `swift format format -i` applied to the seven new Swift source/test files.
- `swiftc -frontend -parse` passed for those files.
- All nine quick-capture tests passed in the coordinated check7 run (`/tmp/synthesis-parallel-check-7.log`): five core tests and four native-model/panel tests. The full run had one unrelated unfinished #35 fixture failure, subsequently corrected; a final complete check remains required.
- Initial background runner completed all six capture states at 1440×900; its log records actual capture save/clear/no-canon assertions and nonactivating native panel checks. Source: `../expansion-parallel-initial/capture.log`.
- Inspected initial writing and error panel PNGs. Found a doubled titlebar/header, an error row expanding the panel from 330 to 801 points, and a low-contrast Save shortcut. Native controls now share the 48pt header, host automatic window sizing is disabled, and the shortcut inherits primary-action contrast. Final rendering after these fixes remains pending.
- Final package check passed 334 tests / 81 suites, strict lint and optimized build. Corrected contact-sheet inspection remains pending after the owner requested a save-and-handoff checkpoint. [Final logs and resume command](../expansion-parallel-checkpoint/README.md).
- No foreground input, live provider request or release.

Physical global-shortcut dispatch, previous-application focus restoration, animation pacing and VoiceOver remain outside background evidence.
