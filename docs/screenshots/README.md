# Screenshots

The README images, refreshed 2026-11-16 for 0.0.3 from the real app with the bundled Aster sample world, at 1440×900 and scaled to 1600 px wide.

| File | Capture state |
| --- | --- |
| `canvas.png`, `canvas-light.png` | `canvas`, `light` |
| `conversation.png` | `conversation` |
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
SYNTHESIS_CAPTURE_STATES=canvas,light,conversation,graph,editor,mechanics-tree,timeline-overview,atlas-regions,review-checks,review-what-if,settings \
SYNTHESIS_CAPTURE_SIZES=1440x900 ./scripts/verify-ui.sh /tmp/synthesis-shots
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-shots   # inspect before copying
sips -Z 1600 /tmp/synthesis-shots/canvas-1440x900.png --out docs/screenshots/canvas.png
```

Captures run in the background against an isolated database and never touch your worlds. The sample artwork is bundled and AI-generated.
