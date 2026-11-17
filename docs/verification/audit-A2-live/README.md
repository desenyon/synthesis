# Audit A2 — live window check (2026-11-16)

`dist/Synthesis.app` built from main was started with `SYNTHESIS_DATABASE_PATH` pointing at a temporary folder (the owner's database untouched) and driven with System Events key events: Return to finish the welcome sheet, ⌘2 for Canvas, ⌘K → "light appearance" → Return. Window pixels were captured with `screencapture -x -o -l <window>` while the app was frontmost.

- `01-launch.jpg`: first launch, welcome sheet over Conversation (dark).
- `02-canvas-dark.jpg`: Canvas bar opaque and dark (captured with the sheet still open in the first run, which exposed the Return bug below).
- `09-canvas-light.jpg`: Canvas bar opaque and light after the palette command; sidebar follows the theme.

Bugs found and fixed during this check: Return in the welcome sheet's name field did nothing (now starts creating), and the command palette ranked "Capture … as an idea" above a matching command, so typing a command name and pressing Return captured text (commands and lore now come first; covered by `CommandPaletteRankingTests`). With Stage Manager on, an app that loses focus shrinks into the side strip, so captures must be taken while it is frontmost.
