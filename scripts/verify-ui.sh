#!/bin/zsh
# Renders every workspace state of the real native app against an isolated database.
# Optional: SYNTHESIS_CAPTURE_SIZES="1440x900,1024x768" SYNTHESIS_CAPTURE_STATES="canvas,graph".
# The runner stays behind other windows and never takes focus.
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh release
synthesis_fixture="$(mktemp -d /tmp/synthesis-ui.XXXXXX)"
synthesis_captures="${1:-$PWD/docs/verification/latest}"
mkdir -p "$synthesis_captures"
export SYNTHESIS_DATABASE_PATH="$synthesis_fixture/workspace.sqlite"
export SYNTHESIS_CAPTURE_DIR="${synthesis_captures:A}"
dist/Synthesis.app/Contents/MacOS/Synthesis | tee "$synthesis_captures/capture.log"
rg -q 'Native captures complete' "$synthesis_captures/capture.log"
print "Native captures: $synthesis_captures"
print "Contact sheets: uv run --with pillow python scripts/contact-sheets.py '$synthesis_captures' [--prune]"
