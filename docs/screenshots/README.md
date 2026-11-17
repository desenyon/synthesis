# Screenshots

README images come from the real app with the bundled Aster sample world, at 1440×900 and scaled to 1600 px wide. `composer.png`, `composer-context.png` and `conversation.png` were refreshed on 2026-11-17 from unreleased main after 0.0.3; the other images retain the inspected 0.0.3 capture set. No live model request produced these authored fixtures.

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

To refresh:

```sh
SYNTHESIS_CAPTURE_STATES=canvas,light,conversation,composer-attached,composer-context,graph,editor,mechanics-tree,timeline-overview,atlas-regions,review-checks,review-what-if,settings \
SYNTHESIS_CAPTURE_SIZES=1440x900 ./scripts/verify-ui.sh /tmp/synthesis-shots
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-shots   # inspect before copying
sips -Z 1600 /tmp/synthesis-shots/canvas-1440x900.png --out docs/screenshots/canvas.png
```

Captures run in the background against an isolated database and never touch your worlds. The sample artwork is bundled and AI-generated.

The context inspector capture displays the actual popover content inline so verification never steals focus. Its position is a capture layout; native popover pointer/keyboard behavior requires a separate interaction check. Latest evidence: [composer-polish](../verification/composer-polish/README.md).
