# Contributing to Synthesis

Thanks for helping. Synthesis is a native macOS app (SwiftUI, AppKit, SQLite) with an embedded offline Excalidraw canvas. This guide covers how to build it, what a good change looks like, and the rules that protect creators' work.

## Getting started

```sh
git clone https://github.com/desenyon/synthesis.git
cd synthesis
./scripts/check.sh          # strict lint, tests and an optimized build
open dist/Synthesis.app
```

You need macOS 14+ and Xcode 26 (or the Swift 6 Command Line Tools with the macOS 26 SDK). Node 22 is only needed if you change `CanvasWeb/` (`npm install && npm run build`, then commit the rebuilt `Sources/SynthesisUI/CanvasBundle`).

Use a throwaway database while developing: `SYNTHESIS_DATABASE_PATH=/tmp/synthesis-dev.sqlite open dist/Synthesis.app`.

## Making a change

1. Open an issue first for anything larger than a small fix, so we can agree on the approach.
2. Keep the change to one purpose and include tests: core behaviour in `Tests/SynthesisCoreTests`, view logic in `Tests/SynthesisUITests`, canvas geometry in `CanvasWeb/tests`.
3. Run `./scripts/check.sh`. For visible changes, also run `./scripts/verify-ui.sh /tmp/captures`, look at the screenshots, and attach before/after images to the pull request.
4. Update the relevant docs (`docs/STATE.md`, feature guides, `CHANGELOG.md` under *Unreleased*).

## Rules that are not negotiable

These protect the creator's ownership of their world (see [AGENTS.md](AGENTS.md) for the full contract):

- **Canon is deliberate.** Nothing the assistant produces may become canon without an explicit, scoped creator action. Proposals become drafts; canon needs its own review.
- **Nothing is hard-deleted.** Removal archives and offers Undo.
- **Data stays local and world-scoped.** No network access outside the subscription harness, no telemetry, and no mixing of worlds.
- **No false affordances.** Every visible control must work or be clearly marked unavailable.
- **Design system.** Colours, controls and sheets come from `Theme.swift` and `Components.swift`. Every workspace starts with `WorkspaceBar`.
- **Canvas stays offline.** Keep the content security policy in `CanvasHost.swift`; no remote fonts, embeds or requests.

## Style

- Swift is formatted with `swift format` (the check runs `swift format lint --strict`). Run `swift format format -i <files>` before committing.
- Write UI text in plain, specific English. Say what will happen ("Send 4 for review"), not what the system is.
- Commit messages: a short imperative summary line, then the why.

## License

By contributing you agree that your contributions are licensed under the [GPL-3.0](LICENSE).
