# Screenshots

README images come from the real app with the bundled Aster sample world, at 1440×900 and scaled to at most 1600 px wide. `composer.png`, `composer-context.png`, `conversation.png`, `layouts.png`, `dashboard.png`, `canvas-light.png`, `graph-detail.png`, `document-tabs.png`, `palette.png`, `navigation.png`, `favorites.png`, `activity.png` `split-workspace.png`, `drag-records.png` `atlas-context.png` and `library-history.png` were refreshed on 2026-11-17 from unreleased main after 0.0.3; the other images retain the inspected 0.0.3 capture set. No live model request produced these authored fixtures.

| File | Capture state |
| --- | --- |
| `canvas.png`, `canvas-light.png` | `canvas`, `light` |
| `conversation.png` | `conversation` |
| `composer.png` | `composer-attached` |
| `composer-context.png` | `composer-context` |
| `graph.png` | `graph` |
| `editor.png` | `editor` |
| `technique-tree.png` | `mechanics-tree` |
| `timeline.png` | `timeline-overview` |
| `atlas.png` | `atlas-regions` |
| `review-checks.png` | `review-checks` |
| `what-if-review.png` | `review-what-if` |
| `settings.png` | `settings` |
| `layouts.png` | `layouts` (expansion #12) |
| `dashboard.png` | `dashboard` (expansion #13, refined) |

To refresh:

```sh
SYNTHESIS_CAPTURE_STATES=canvas,light,conversation,composer-attached,composer-context,graph,editor,mechanics-tree,timeline-overview,atlas-regions,review-checks,review-what-if,settings \
SYNTHESIS_CAPTURE_SIZES=1440x900 ./scripts/verify-ui.sh /tmp/synthesis-shots
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-shots   # inspect before copying
sips -Z 1600 /tmp/synthesis-shots/canvas-1440x900.png --out docs/screenshots/canvas.png
```

Captures run in the background against an isolated database and never touch your worlds. The sample artwork is bundled and AI-generated.

The context inspector capture displays the actual popover content inline so verification never steals focus. Its position is a capture layout; native popover pointer/keyboard behavior requires a separate interaction check. Latest evidence: [composer-polish](../verification/composer-polish/README.md).

Workspace layouts: [expansion-012](../verification/expansion-012/README.md). The four named arrangements are saved through the real layout API in isolated capture data; they are not preloaded into user worlds.

Dashboard: [expansion-013](../verification/expansion-013/README.md). Project and activity fixtures are created through actual persistence APIs; no provider responses are fabricated in production.

Light Canvas: expansion #14, `verification/expansion-014/after`, inspected before PNG pruning.

Detailed Graph: expansion #15, `verification/expansion-015/refined`, using actual record artwork in an isolated fixture.

Document tabs: expansion #16, `verification/expansion-016`, with pinned and real opened records.

`palette.png` comes from expansion #22's 1440×900 native faction-filter capture. [Search evidence](../verification/expansion-022/README.md) covers real relationship and status/date filters. [#21 evidence](../verification/expansion-021/README.md) additionally covers maps/scenes/settings/activity. Both include narrow, light and Manual states.

`navigation.png` comes from expansion #23’s final Categories tab at 1440×900. The section order, hidden categories and pins are real isolated preferences. [Evidence](../verification/expansion-023/README.md).

`favorites.png` comes from expansion #24’s final Favorites manager at 1440×900. All names and pins resolve to persisted records/collections in the isolated sample world. [Evidence](../verification/expansion-024/README.md).

Activity: `activity.png` is `changes-search` at 1440×900 from [expansion-025](../verification/expansion-025/README.md), showing actual fixture mutations recorded through the database triggers.

Split workspace: `split-workspace.png` is `split-atlas` at 1440×900 from expansion #26's final `verified` set. Both panes refer to actual sample-world records; no model request was made. [Evidence](../verification/expansion-026/README.md).

Record drag: `drag-records.png` is `drag-targets` at 1440×900 from [expansion #27](../verification/expansion-027/README.md). The isolated sample has an actual favorite record and the native drag-target state; it does not claim a physical mouse gesture was captured.

`atlas-context.png`: expansion #28, `atlas-context-return` at 1440×900, captured after opening the linked source and returning through Back. All three nine-state contact sheets were inspected.

`library-history.png`: expansion #29, `global-history-library`, 1440×900 from the final compact-control refinement. [Evidence](../verification/expansion-029/README.md).

`keyboard-link.png`: expansion #30, `keyboard-link`, 1440×900, unreleased main. [Evidence](../verification/expansion-030/README.md).

`startup.png`: expansion #31, `startup-settings`, 1440×900, unreleased main. [Evidence](../verification/expansion-031/README.md).

`focus-writing.png`: expansion #32, `focus-writing`, 1440×900 from the final set; temporary native Focus on unreleased main. [Evidence](../verification/expansion-032/README.md).
