# Handoff — 2026-11-13

For the next agent session. Read `AGENTS.md` first, then this file, then `docs/STATE.md` and `docs/ROADMAP.md`.

## Continuation correction — 2026-11-13

The owner explicitly selected this worktree and Claude’s implementation as the baseline after an older `main` build was opened by mistake. Use `/Users/desenyon/.zeron/worktrees/synthesis/swift-falcon` and this branch; do not port the unmerged `main` SwiftFlow redesign over this canvas.

The existing `dist/Synthesis.app` was opened for owner review and its Excalidraw canvas inspected. The old process was stopped, old bundles retired, and the local database backed up. No new feature verification or provider call was performed during this correction. The pre-existing uncommitted rules-lab changes are preserved and are not included in the review build. Wait for the requested owner review before further feature changes. Run checks in the background; the focus-taking self-test needs a separately agreed review window.

## Where things stand

Branch `zeron/you-are-an-elite-product-designer-ux` on `github.com/desenyon/synthesis` (public). `main` there is the pre-audit history. Everything described below is committed and pushed unless a line says otherwise.

Done and verified this cycle:

1. **Product audit and unified design system** — `docs/verification/AUDIT.md`.
2. **Safe AI depth** — ranked, recorded context; staged proposals with per-change review; `@` mentions; quick capture; Markdown import/export; Review workspace with a local consistency check.
3. **Subscription harness by default** — `Sources/SynthesisCore/HarnessTransport.swift`. Claude Code (no tools) or Codex (read-only sandbox), API key optional. Both verified live once. See `docs/AI_SETUP.md`.
4. **Canvas on the Excalidraw engine** — `CanvasWeb/` (TypeScript source) builds into `Sources/SynthesisUI/CanvasBundle` (committed, served offline through the `synthesis-canvas://` scheme). `Sources/SynthesisUI/CanvasHost.swift` is the native session and bridge; `CuratedCanvas.swift` is the workspace.

## How the canvas works

- Record cards are ordinary Excalidraw groups: a rectangle carrying `customData {synthesis:"card", recordID, hash}` plus text parts (`role`: category, title, body, state) and optional artwork (`role:"art"`). `CanvasWeb/src/cards.ts` rebuilds the text when the record or theme changes.
- Stored relationships between entities on a board become bound arrows with `customData {synthesis:"relation", relationID}`. Deleting such an arrow hides it on that board only (`hiddenRelations`); editing its label renames the relationship through the audited store call.
- An arrow the creator draws between two entity cards raises a "Is this a relationship?" sheet. Saving creates a draft relationship; declining leaves a plain arrow.
- Excalidraw's dark theme inverts the canvas with a CSS filter, so Synthesis colours are stored pre-inverted (`palette.ts`). WebKit lacks `CanvasRenderingContext2D.filter`, so `canvasFilter.ts` supplies the image un-inversion Excalidraw expects.
- Board rows store `{format:"excalidraw", scene, hiddenRelations, legacy?}`. Boards in the earlier `CanvasDocument` layout (still used to seed the sample world and Graph's "Copy to canvas") are converted on first open and the original is kept under `legacy`.
- One `CanvasSession` and web view live for the whole run (`Studio.canvas()`), so edits still save after navigation. Quit waits for a final flush.

To change the canvas: edit `CanvasWeb/src`, then `cd CanvasWeb && npm install && npm run build`, then `./scripts/build.sh release`. Commit the rebuilt `CanvasBundle`.

## Verification commands

```sh
./scripts/check.sh                                   # strict lint, 45 tests, optimized build
./scripts/verify-ui.sh docs/verification/latest      # captures, stays in the background
./scripts/selftest-ui.sh docs/verification/latest    # real pointer/key events; takes focus briefly
uv run --with pillow python scripts/contact-sheets.py docs/verification/latest --prune
SYNTHESIS_LIVE_HARNESS=claude-code ./scripts/test.sh --filter LiveHarnessTests   # uses a little subscription quota
```

## Known gaps, most important first

1. **Posted mouse drags cannot drive the web canvas.** WebKit reports `buttons: 0` for `mouseDragged` events posted to a window, so the self-test drags cards with pointer events dispatched inside the page (`window.synthesis.testDrag`, which also shields the drag from the person's real pointer). Clicks and double-clicks are still posted as real window events. Excalidraw only handles a move whose target is an HTML element and one move per animation frame; keep that in mind when extending the test.
2. **Bundle size.** `CanvasBundle` is 8.4 MB including Mermaid diagram chunks and 52 locale files that could be pruned. CJK handwriting font (Xiaolai) is deliberately left out.
3. **Live model path** is verified for one request per harness only. Streaming UI, Stop, and long answers have not been watched in the running app.
4. Earlier open items still stand: large boards/graphs unmeasured, no VoiceOver walk-through, trackpad gestures unverified, crash recovery for unsaved editor text.

Resolved since the first handoff: card dragging verified (exact delta, arrows stay attached, move saved); the web view is mounted once in the shell (`ConnectedRoot`) and positioned under a transparent area reported by the Canvas workspace through `CanvasFrameKey`, so it is never re-parented and background captures of every canvas state render; "Reference" for selected cards, card artwork (set, replace, remove) and "Show on canvas" (editor menu, Library row menu) are rebuilt. Self-test: 17 of 17 in one run.

## Owner direction not yet implemented

- The owner shared two visual references on 2026-11-13: a storage card whose segmented bar is made of glowing dot-matrix cells per category, and a glass toggle with a pixel-art moon that dissolves. Both now exist in `Sources/SynthesisUI/PixelComponents.swift`: `WorldComposition` with `DotMatrixBar` heads the Library list, and `PixelThemeToggle` is the appearance switch in the sidebar footer and Settings. Captured and inspected in both themes; the dissolve animation itself has not been watched. The same language could extend to the AI Assisted / Manual switch, the Review counts and a per-world overview — ask the owner before spreading it further.
- "Develop each feature to the max": next roadmap items are the rules and power-system lab, hypothetical branches, canvas depth, timeline and atlas depth (see `docs/ROADMAP.md`).

## Rules that are easy to break

- Never hard-delete; archive with Undo.
- Nothing the model produces becomes canon; `resolveChange` and `promote` require the ID as confirmation and the engine must not gain a path to them.
- The canvas must stay offline: no CDN fonts, no embeds, no network. The content security policy in `CanvasHost.swift` enforces this.
- The self-test steals focus for a few seconds; do not run it repeatedly while the owner is working.
- Do not edit protected sections of `AGENTS.md`.

## Prompt to continue

> Continue building Synthesis in this repository. Read `AGENTS.md`, then `docs/HANDOFF.md`, `docs/STATE.md` and `docs/ROADMAP.md`, and check `git status` and `git log --oneline | head`. Work on branch `zeron/you-are-an-elite-product-designer-ux`.
>
> In order: (1) rerun `./scripts/selftest-ui.sh docs/verification/latest` once and fix anything that fails in the Excalidraw canvas, especially card dragging; (2) mount the canvas web view once at the shell level so it is never re-parented, then confirm background captures of `empty-canvas` render; (3) rebuild the missing canvas actions (reference a selected card in the conversation, attach artwork to a card, "show on canvas" from a record); (4) watch the pixel theme toggle animate in the running app and, if I confirm, carry the dot-matrix and pixel-glass language from `PixelComponents.swift` to the AI Assisted / Manual switch and a world overview; (5) continue the roadmap with the rules and power-system lab, then hypothetical branches.
>
> Keep every change verified: run `./scripts/check.sh`, capture with `./scripts/verify-ui.sh`, inspect the contact sheets, update `docs/STATE.md`, `docs/ROADMAP.md` and `docs/HANDOFF.md`, commit and push after each working stage. Use the local subscription harness for any model calls and keep them minimal. Before you run low on usage, update `docs/HANDOFF.md` and give me a new continuation prompt.
