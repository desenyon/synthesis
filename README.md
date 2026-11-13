# Synthesis

A native macOS creative studio for building fictional worlds. Light by default, conversation first, with a fully independent Manual mode. Development only; no releases or public deployment.

## Rebuild in progress

The actual app is being built in **SwiftUI + AppKit**, with SQLite persistence and an `NSTextView` rich-text editor. This replaces the abandoned web scaffold and design previews. There was no working frontend to migrate. The owner explicitly permitted a native alternative to GPUI; Swift is installed on this Mac while the Rust/GPUI toolchain is absent.

The protected rules remain: AI cannot approve canon, data belongs to its world, revisions survive edits, and no provider calls happen in Manual mode. See [current state](docs/STATE.md) for observed checks and gaps, and [roadmap](docs/ROADMAP.md) for the gate sequence.

## Development

Requirements: macOS 14+, Swift 6 toolchain / Apple Command Line Tools. No external package dependencies.

```sh
export EDITOR=vim VISUAL=vim GIT_EDITOR=vim
./scripts/test.sh
./scripts/build.sh
open dist/Synthesis.app
```

Scripts are established as the native implementation lands. Data will live in `~/Library/Application Support/Synthesis/synthesis.sqlite`. `SYNTHESIS_DATABASE_PATH` selects an alternate development/test database. The original schema is retained; native migrations are additive. No lore is automatically imported or replaced.

The unfinished TypeScript backend is preserved under `legacy/web/`, and earlier HTML studies under `docs/design/` are superseded historical references. Neither is an application entry point.
