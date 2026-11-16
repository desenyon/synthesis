# README screenshots

Captured from the real native application at source commit `0148d8a`, using an isolated database and the clearly labeled Aster sample world. Logical window size: 1440×900; PNG backing resolution: 2880×1800. Original capture pixels are preserved. These are not mockups or generated UI images. The Atlas and Canvas contain optional bundled sample artwork; this does not demonstrate runtime image generation.

Capture runs stayed in the background, rejected model requests and did not access the owner's working database. All six images were inspected in a contact sheet. Background captures establish appearance, not physical interaction coverage.

To refresh after a visual change:

```sh
SYNTHESIS_CAPTURE_STATES=conversation-home,canvas,editor,graph,atlas,settings \
SYNTHESIS_CAPTURE_SIZES=1440x900 \
./scripts/verify-ui.sh /tmp/synthesis-readme-screenshots
uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-readme-screenshots
```

Inspect the contact sheet, then copy each `<state>-1440x900.png` here as `<state>.png` and copy `capture.log`. Update the source commit above. Root README paths are relative so the images display on GitHub and in local Markdown viewers.
