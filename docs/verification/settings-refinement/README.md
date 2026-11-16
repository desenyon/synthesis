# Settings refinement verification

Actual native app, isolated fixture databases, model transport rejects requests. No focus-taking automation.

- `./scripts/check.sh`: strict lint, 94 tests / 21 suites, optimized development build.
- `SYNTHESIS_CAPTURE_STATES=settings,settings-writing,settings-assistant,settings-assistant-details,settings-world,settings-data,settings-search,settings-no-results,light-settings,light-settings-writing,onboarding,sheet-record,manual-settings,settings-collapsed,settings-model-search,preferences-editor,preferences-library SYNTHESIS_CAPTURE_SIZES=1440x900,1024x768 ./scripts/verify-ui.sh /tmp/synthesis-settings-final`
- `SYNTHESIS_CAPTURE_STATES=settings,settings-world,settings-assistant-details,settings-search,manual-settings,preferences-library SYNTHESIS_CAPTURE_SIZES=720x800 ./scripts/verify-ui.sh /tmp/synthesis-settings-compact`
- `uv run --with pillow python scripts/contact-sheets.py <capture-dir>` for each directory. All three contact sheets inspected (40 final captures).

Observed: aligned open rows, compact section menu, readable light/dark surfaces, local world identity controls, expanded provider details, search matches and empty state. Changed-preference captures show narrower/larger writing, hidden word count, compact Library rows and hidden category/history navigation. Long sections scroll in compact windows; physical scrolling/focus traversal was not exercised.

Native sheets are drawn inline in background captures, not exercised as modal interactions. No native open/save-dialog walkthrough or live subscription request. The pre-existing A2 live-capture blocker and unapproved C2/C3 remain separate.
