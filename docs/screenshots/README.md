# README screenshots

Screenshots were refreshed on 2026-11-16. Atlas is from the named-map implementation checkpoint (parent `bbc1c0f` plus its map changes), with evidence in `docs/verification/atlas-maps`. The other six are from Mechanics commit `bbc1c0f`; Mechanics uses its separate verification capture and the five other views share the capture log here. Captured from the real native application, using an isolated database and the clearly labeled Aster sample world. Logical window size: 1440×900; PNG backing resolution: 2880×1800. Original capture pixels are preserved. These are not mockups or generated UI images. The Atlas and Canvas contain optional bundled sample artwork; this does not demonstrate runtime image generation.

Capture runs stayed in the background, rejected model requests and did not access the owner's working database. All seven images were inspected in contact sheets, including `docs/verification/mechanics` and `docs/verification/atlas-maps`. Background captures establish appearance, not physical interaction coverage.

To refresh after a visual change:

```sh
SYNTHESIS_CAPTURE_STATES=conversation-home,canvas,editor,graph,atlas,settings,mechanics \
SYNTHESIS_CAPTURE_SIZES=1440x900 \
./scripts/verify-ui.sh /tmp/synthesis-readme-screenshots
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-readme-screenshots
```

Inspect the contact sheet, then copy each `<state>-1440x900.png` here as `<state>.png` and copy `capture.log`. Update the per-image source note above. Root README paths are relative so the images display on GitHub and in local Markdown viewers.
