# Main checkout consolidation — 2026-11-13

Owner instruction: make the reviewed app the primary version, remove other worktrees, update docs, push to GitHub and open the app for review.

## Execution plan

1. Preserve repository history, unfinished source, local artifacts and the existing SQLite database outside the repository.
2. Checkpoint the rules backend already included in the review binary, correcting formatting without changing behavior. Verify full checks.
3. Integrate the reviewed source tree into `main` at `/Users/desenyon/Developer/synthesis`, retaining both histories and replacing the superseded SwiftFlow implementation.
4. Verify the consolidated checkout, update active documentation and remove the extra worktree registration after preserving its contents.
5. Push `main` without rewriting remote history, make it GitHub's default branch, and launch `dist/Synthesis.app` from the primary checkout.

## Evidence so far

- Git fetch confirmed no new remote work beyond the reviewed baseline.
- Private recovery archive includes a Git bundle, original uncommitted files/patch and a SQLite backup. It is outside the repository and must not be pushed.
- Pre-integration `./scripts/check.sh`: full strict lint, 51 native tests and optimized development build passed after formatting the preserved rules files.
- Rules backend is a checkpoint, not a completed Rules Lab UI. Migration 0006, world-scoped rules/scenarios, context/Markdown rules and JSON export schema 5 are retained from the previous working tree.
