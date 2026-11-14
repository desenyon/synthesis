# Main checkout consolidation — 2026-11-13

Owner instruction: make the reviewed app the primary version, remove other worktrees, update docs, push to GitHub and open the app for review.

## Execution plan

1. Preserve repository history, unfinished source, local artifacts and the existing SQLite database outside the repository.
2. Checkpoint the rules backend already included in the review binary, correcting formatting without changing behavior. Verify full checks.
3. Integrate the reviewed source tree into `main` at `/Users/desenyon/Developer/synthesis`, retaining both histories and replacing the superseded SwiftFlow implementation.
4. Verify the consolidated checkout, update active documentation and remove the extra worktree registration after preserving its contents.
5. Push `main` without rewriting remote history, make it GitHub's default branch, and launch `dist/Synthesis.app` from the primary checkout.

## Integration and verification

- Git fetch confirmed no new remote work beyond the reviewed baseline.
- Private recovery archive includes a Git bundle, original uncommitted files/patch and a SQLite backup. It is outside the repository and must not be pushed.
- Pre-integration `./scripts/check.sh`: full strict lint, 51 native tests and optimized development build passed after formatting the preserved rules files.
- Rules backend is a checkpoint, not a completed Rules Lab UI. Migration 0006, world-scoped rules/scenarios, context/Markdown rules and JSON export schema 5 are retained from the previous working tree.

- Merge `12159c2` retains old main and reviewed branch histories. Before documentation updates, `git diff HEAD zeron/you-are-an-elite-product-designer-ux` was empty: main exactly matched the reviewed source plus the rules checkpoint.
- Consolidated `./scripts/check.sh`: full strict lint, 51 native tests and optimized `dist/Synthesis.app` build passed from the primary checkout.
- `cd CanvasWeb && npm run typecheck && npm test && npm run build`: passed; six tests, rebuilt bundle unchanged.
- `SYNTHESIS_CANVAS_AUDIT=1 SYNTHESIS_CAPTURE_STATES=canvas SYNTHESIS_CAPTURE_SIZES=1440x900 ./scripts/verify-ui.sh test-results/main-consolidation`: 17 engine/persistence/shutdown checks passed. Actual native/WebKit canvas capture inspected.
- `python3 scripts/check-capture-isolation.py dist/Synthesis.app/Contents/MacOS/Synthesis`: passed.
- `git worktree list --porcelain`: one worktree, `/Users/desenyon/Developer/synthesis`, branch `main`. The former worktree was clean before removal; source snapshot and ignored builds/captures were archived privately first.
- README, handoff, architecture, state, roadmap and decisions now identify the primary location. AGENTS.md received one operational path clarification, recorded in LEARNINGS.md; protected rules are unchanged.
- GitHub push succeeded; remote `HEAD` and the repository default branch both resolve to `main`. No force push or release.
- Launched `/Users/desenyon/Developer/synthesis/dist/Synthesis.app` for owner review. Verified the running executable path and visually inspected the foreground Canvas: existing records, custom entity cards, labeled relationship, floating tools and composer render correctly. Existing local data remains intact. This launch inspection is not a full foreground interaction audit; no model request was made. User-data screenshots were not committed.

The feature audit's remaining gaps still apply. This consolidation does not claim new feature completeness, releases, deployments or live model verification.
