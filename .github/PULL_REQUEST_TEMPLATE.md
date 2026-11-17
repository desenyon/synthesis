## What and why

<!-- One or two sentences: what changes for the creator, and why. Link the issue. -->

## How it was checked

- [ ] `./scripts/check.sh` passes
- [ ] New or changed behaviour has tests
- [ ] Visible changes: captured with `./scripts/verify-ui.sh` and inspected (before/after attached)
- [ ] `CanvasWeb` changes: `npm test`, `npm run typecheck`, bundle rebuilt and committed

## Safety

- [ ] Nothing becomes canon without an explicit creator action
- [ ] Removal archives with Undo; no hard deletes
- [ ] No new network access, telemetry or cross-world data access
- [ ] Docs and `CHANGELOG.md` (Unreleased) updated
