# Verification evidence

Each folder holds the captures, contact sheets and logs from one verification pass, named after the work it checked (for example `audit-B3`, `interaction-0.0.2`, `audit-A2-live`). They are historical evidence: paths, counts and screenshots reflect the code at the time. The current summary of what is verified is in [STATE](../STATE.md), with per-slice detail in [PROGRESS](../PROGRESS.md).

Captures come from the real app (`./scripts/verify-ui.sh`) or its foreground self-test (`./scripts/selftest-ui.sh`), always against an isolated database with the bundled Aster sample world.
