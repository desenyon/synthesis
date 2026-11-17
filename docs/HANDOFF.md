# Handoff — 2026-11-16, release 0.0.3

Start here when picking up Synthesis.

## Where things are

- Canonical checkout: `/Users/desenyon/Developer/synthesis`, branch `main` (also the GitHub default). Build and open `dist/Synthesis.app` here; no other worktrees are current.
- Releases: v0.0.1, v0.0.2 and v0.0.3 are full GitHub releases with an Apple Silicon ZIP, checksums, license and third-party notices. The app is ad-hoc signed, not notarized. 1.0 is the future public launch.
- License: GPL-3.0 (owner choice, 2026-11-16).
- The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is not agent-owned. Leave it untouched and out of commits.

## Read first

1. [AGENTS.md](../AGENTS.md): the product contract and protected rules (canon approval, archive-not-delete, privacy, verification honesty).
2. [STATE](STATE.md): what is verified, with exact checks.
3. [NEXT_PASS](NEXT_PASS.md) and [ROADMAP](ROADMAP.md): what remains.
4. [ARCHITECTURE](ARCHITECTURE.md): modules, migrations (0001–0013), portable format v7, JSON schema 10.

## Current shape

Native SwiftUI/AppKit app over SQLite, with the Canvas on an embedded offline Excalidraw bundle (`CanvasWeb/` → `Sources/SynthesisUI/CanvasBundle`). Workspaces: Conversation, Canvas, Library and editor, Graph, Timeline, Atlas, Review, Worlds, Settings, plus Mechanics on entities. The assistant is Codex or Claude Code through the creator's own subscription, with no tools or files; Manual mode blocks requests in the core.

0.0.3 added what-if worlds with reviewed merge-back, technique trees, Atlas regions, Timeline views and reordering, extended Review checks, crash recovery, `.synthesis` Finder integration and explicit-click Codex image generation.

## How to verify

```sh
./scripts/check.sh                       # lint, 158 tests, optimized build
./scripts/verify-ui.sh /tmp/captures     # background captures of every state
./scripts/selftest-ui.sh /tmp/selftest   # 19 real pointer/key checks; takes focus briefly
cd CanvasWeb && npm test && npm run typecheck
```

For live-window checks use an isolated instance (`SYNTHESIS_DATABASE_PATH` in a temp folder) and capture with `screencapture -l` while it is frontmost; Stage Manager shrinks unfocused windows.

## Open work

- A live Codex image generation has never been run; it needs the owner's approval because it spends subscription allowance.
- VoiceOver walkthrough, trackpad feel and animation pacing are unverified.
- Not built: three-way text merge for what-ifs, drag-to-reorder events, assistant proposals for technique requirements and regions, cosmology-specific tools, continuous file sync, notarized distribution.
- Audit C2 (lighter palette) is unapproved because it reverses the owner's black-studio direction.

Next agent: use [RUN_PROMPT](RUN_PROMPT.md).
