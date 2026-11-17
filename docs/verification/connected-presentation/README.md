# Connected presentation verification

2026-11-16, native app, isolated sample database. Final source in the commit containing this evidence.

- `./scripts/check.sh`: strict lint, 102 tests / 23 suites, optimized development build.
- Canvas typecheck, nine Node tests, bundled build passed.
- Native WebKit audit: 22 checks passed; see canvas-audit.log. Includes actual PNG and saved scene checks.
- 28 captures at 1440×900 and 1024×768; both contact sheets and exported PNG inspected. Clean Canvas and final Graph captures replace the audit-mutated viewport.
- Graph overview below 55% displays title/state; zoom restores descriptions. Wide selection docks details, compact selection floats them.

No foreground self-test, menu keyboard interaction, native save dialog, live subscription call or paid generation. Animations are implemented, not certified by still captures. No user database or running window was altered.
