# Run prompt — continue Synthesis

Copy this to a coding agent working in this repository.

> Work in `/Users/desenyon/Developer/synthesis` on `main`. Read `AGENTS.md`, then `docs/HANDOFF.md`, `docs/STATE.md`, `docs/NEXT_PASS.md` and `docs/ROADMAP.md`. Synthesis is a native SwiftUI/AppKit + SQLite worldbuilding studio with an offline Excalidraw Canvas; the assistant runs only through the creator's Codex or Claude Code subscription.
>
> Pick the next unfinished item from the "Open work" list in `docs/HANDOFF.md` (skip anything that needs owner approval, such as a live paid model request or the C2 palette change, unless I approve it). Build it as a complete vertical slice: persistence with an additive migration if needed, core logic with tests, UI built from `Theme.swift` and `Components.swift`, empty and error states, and portability in `.synthesis` and JSON exports.
>
> Keep the protected rules: nothing becomes canon without an explicit creator action; removal archives with Undo; data stays local and world-scoped; no network access outside the subscription harness; every visible control works or says it is unavailable.
>
> After each slice: run `./scripts/check.sh`; capture affected states with `./scripts/verify-ui.sh <dir>` and inspect the contact sheets from `scripts/contact-sheets.py`; fix what the captures show; add a dated entry to `docs/PROGRESS.md` with the checks you actually ran; update `docs/STATE.md`, the relevant feature guide and `CHANGELOG.md` (Unreleased); commit with a clear message and push. Do not publish a release unless I ask. Leave the untracked `docs/DESIGN_AGENT_BRIEF.md` alone.
>
> Finish with a short report: what was built, the exact checks run and their results, what is still open, and anything that needs my decision.
