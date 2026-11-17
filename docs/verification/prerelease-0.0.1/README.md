# 0.0.1 verification — 2026-11-16

Canonical main over 82ab008. Actual native app, temporary databases, no provider usage or foreground activation. Owner design brief remains untouched.

- `./scripts/check.sh`: strict Swift lint, 120 tests in 27 suites, optimized native build.
- Canvas: TypeScript check, 9 Node tests and rebuilt committed offline bundle.
- 26 initial captures, 14 final refinement captures, 3 README captures and 1 packaged-app audit capture. Every contact sheet inspected. Final graph cards retain readable overview titles; selection no longer shifts the viewport. Dark/light, compact, collapsed, Manual, loading, conversation, companion, timeline tree, Atlas and Review states included.
- Four native sidebar pixel assertions passed on final Graph/light Graph at both sizes.
- The exact distribution ZIP was extracted and its signature verified. Its executable ran 24 background Canvas checks: engine drag/undo/redo, locked relationship endpoints and label inspection, record sync, archive, artwork reload, Manual mode, layout, PNG export, persistence, failed-save guards and reviewed placement.
- `canvas-export.png` is the actual engine export and was inspected. The package screenshot is the post-audit viewport (deliberately moved by the checks), not the default board composition.
- `scripts/package-prerelease.sh`: syntax checked; ad-hoc signature verified; ZIP and SHA256SUMS generated. No credentials or user databases are packaged.

The initial capture invocation rejected the mistaken state name `canvas-companion` before rendering; rerun with the real `companion` state completed. Initial native tests exposed a missing-source event acceptance failure; repaired and retested. Final results above supersede those attempts.

No foreground native pointer/keyboard/trackpad session, timing/performance certification, VoiceOver walkthrough, live subscription request, Intel or macOS 14 device run, or notarization. Background captures show settled rendering; synthetic WebKit engine events are not a physical native interaction walkthrough.
