# App screenshots

Refreshed 2026-11-16 for 0.0.1: eight actual native screenshots at 1440×900, inspected in contact sheets. Sidebar is 284pt. These captures use isolated Aster sample data, not the owner's worlds. Artwork is bundled sample imagery; no runtime image generation is implied.

Current evidence and commands: [0.0.1 verification](../verification/prerelease-0.0.1/README.md). States: conversation-home, canvas, editor, graph, mechanics, atlas-linked (saved as atlas.png), timeline and settings. Capture via `SYNTHESIS_CAPTURE_STATES=... SYNTHESIS_CAPTURE_SIZES=1440x900 ./scripts/verify-ui.sh /tmp/synthesis-shots`, then `uv run --with pillow python scripts/contact-sheets.py /tmp/synthesis-shots` and inspect before copying. Bitmap backing scale depends on the capture display; viewport dimensions remain explicit in capture.log.

Background captures establish appearance, not physical interaction, live subscription behavior or generated imagery.
