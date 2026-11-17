# Handoff — 2026-11-17, full expansion in progress

Start here when picking up Synthesis.

## Where things are

- Canonical checkout: `/Users/desenyon/Developer/synthesis`, branch `main` (also the GitHub default). Build and open `dist/Synthesis.app` here; no other worktrees are current.
- Releases: v0.0.1, v0.0.2 and v0.0.3 are full GitHub releases with an Apple Silicon ZIP, checksums, license and third-party notices. The app is ad-hoc signed, not notarized. 1.0 is the future public launch.
- License: GPL-3.0 (owner choice, 2026-11-16).
- The owner's untracked `docs/DESIGN_AGENT_BRIEF.md` is not agent-owned. Leave it untouched and out of commits.

## Read first

1. [AGENTS.md](../AGENTS.md): the product contract and protected rules (canon approval, archive-not-delete, privacy, verification honesty).
2. [STATE](STATE.md): what is verified, with exact checks.
3. [EXPANSION](EXPANSION.md) and [EXPANSION_SOURCE](EXPANSION_SOURCE.md): all 394 requirements, individual acceptance and exact source. Then [ROADMAP](ROADMAP.md) and [COMPOSER_CONTEXT](COMPOSER_CONTEXT.md).
4. [ARCHITECTURE](ARCHITECTURE.md): modules, migrations (0001–0014), portable format v8, JSON schema 11.

## Active expansion

All 394 requirements remain individually tracked in EXPANSION. **#1–#13 verified; #14 light-mode separation is next.** Latest check: 196 tests / 50 suites, strict lint and optimized build. #13 has 20 final inspected background captures; no foreground events or subscription requests.

## Current shape

Native SwiftUI/AppKit app over SQLite, with the Canvas on an embedded offline Excalidraw bundle (`CanvasWeb/` → `Sources/SynthesisUI/CanvasBundle`). Workspaces: Conversation, Canvas, Library and editor, Graph, Timeline, Atlas, Review, Worlds, Settings, Dashboard, plus Mechanics on entities. The assistant is Codex or Claude Code through the creator's own subscription, with no tools or files; Manual mode blocks requests in the core.

0.0.3 added what-if worlds with reviewed merge-back, technique trees, Atlas regions, Timeline views and reordering, extended Review checks, crash recovery, `.synthesis` Finder integration and explicit-click Codex image generation.

Unreleased on main: the supplied World assistant composer reference is implemented across full chat, companions and compact bars. Real lore/map/board/history attachments, local context inspection, per-world persisted scope/exclusions and Explore versus Propose use one core request builder. Restricted context withholds previous messages. Explore discards model proposal blocks in the core; Propose retains explicit review. No API credentials or broader agent filesystem access were introduced. [Usage and boundaries](COMPOSER_CONTEXT.md).

The follow-up chatbox refinement uses the existing app palette and bundled Inter, a single adaptive toolbar, quieter attachment chips and a saved-shortcut hint. Keep Canon protected and provider disclosure below the input; preserve the draft handoff guards when changing presentation. Current evidence is in STATE.

## How to verify

```sh
./scripts/check.sh                       # strict lint, native tests, optimized build
./scripts/verify-ui.sh /tmp/captures     # background captures of every state
./scripts/selftest-ui.sh /tmp/selftest   # 19 real pointer/key checks; takes focus briefly
cd CanvasWeb && npm test && npm run typecheck
```

Use background captures while the owner works. Foreground self-tests and live-window walkthroughs take focus and need an isolated/authorized session. For those checks use an isolated instance (`SYNTHESIS_DATABASE_PATH` in a temp folder) and capture with `screencapture -l` while it is frontmost; Stage Manager shrinks unfocused windows.

## Open work

- The owner requires the entire expansion, in numerical order. Continue the first unverified item in EXPANSION; implement shared prerequisites when necessary and verify each numbered requirement separately. #1–#13 are verified. Do not count existing partial behavior as completion. Preserve sidebar composition, canon approval and subscription isolation.
- The new composer still needs foreground popover/keyboard, VoiceOver and animation-feel verification. Request context is previewed at Send; historical answers retain source references, not a full immutable workspace-index snapshot.
- A live Codex image generation has never been run; it needs the owner's approval because it spends subscription allowance.
- VoiceOver walkthrough, trackpad feel and animation pacing are unverified.
- Not built: three-way text merge for what-ifs, drag-to-reorder events, assistant proposals for technique requirements and regions, cosmology-specific tools, continuous file sync, notarized distribution.
- The renewed expansion explicitly authorizes graphite with optional OLED (#1); this supersedes the previous content-background choice. It does not authorize relaxing privacy, approval or subscription-only rules.

Next agent: use [RUN_PROMPT](RUN_PROMPT.md).
