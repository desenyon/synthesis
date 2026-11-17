# Run prompt — continue Synthesis

Copy this to a coding agent working in this repository.

> Work in `/Users/desenyon/Developer/synthesis` on `main`. Read `AGENTS.md`, then `docs/HANDOFF.md`, `docs/STATE.md`, `docs/EXPANSION.md`, `docs/EXPANSION_SOURCE.md`, `docs/COMPOSER_CONTEXT.md` and `docs/ROADMAP.md`. Synthesis is a native SwiftUI/AppKit + SQLite worldbuilding studio with an offline Excalidraw Canvas; the assistant runs only through the creator's Codex or Claude Code subscription.
>
> Implement every expansion requirement in numerical order from `docs/EXPANSION.md`. Start at the first unverified item, account for each separately, and continue iterating. Do not mark partial functionality complete. Record specific conflicts or external prerequisites as Decision needed while continuing independent work. Build it as a complete vertical slice: persistence with an additive migration if needed, core logic with tests, UI built from `Theme.swift` and `Components.swift`, empty and error states, and portability in `.synthesis` and JSON exports.
>
> Keep the protected rules: nothing becomes canon without an explicit creator action; removal archives with Undo; data stays local and world-scoped; no network access outside the subscription harness; every visible control works or says it is unavailable.
>
> The shared composer/context slice and its 2026-11-17 visual refinement are on main after 0.0.3. Preserve its core-enforced Explore/Propose choice, draft handoff guards and record exclusions through archive/restore. Use shared domain models and components for the full expansion, rather than isolated demo controls. Do not introduce hosted API-key settings: the protected subscription-only boundary still applies. Graphite with optional OLED is now explicitly authorized. Keep tests in the background while I work; do not run the foreground self-test or spend subscription allowance without authorization.
>
> After each slice: run `./scripts/check.sh`; capture affected states with `./scripts/verify-ui.sh <dir>` and inspect the contact sheets from `scripts/contact-sheets.py`; fix what the captures show; add a dated entry to `docs/PROGRESS.md` with the checks you actually ran; update `docs/STATE.md`, the relevant feature guide and `CHANGELOG.md` (Unreleased); commit with a clear message and push. Do not publish a release unless I ask. Leave the untracked `docs/DESIGN_AGENT_BRIEF.md` alone.
>
> Finish with a short report: what was built, the exact checks run and their results, what is still open, and anything that needs my decision.
