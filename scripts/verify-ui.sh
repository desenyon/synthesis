#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
synthesis_fixture="$(mktemp -d /tmp/synthesis-ui.XXXXXX)"
trap 'rm -rf "$synthesis_fixture"' EXIT
synthesis_captures="${1:-$PWD/docs/verification/latest}"
mkdir -p "$synthesis_captures"
# Never replace or launch the developer's running app bundle.
./scripts/build.sh release "$synthesis_fixture/SynthesisVerification.app"
python3 scripts/check-capture-isolation.py "$synthesis_fixture/SynthesisVerification.app/Contents/MacOS/Synthesis"
export SYNTHESIS_DATABASE_PATH="$synthesis_fixture/workspace.sqlite"
export SYNTHESIS_CAPTURE_DIR="${synthesis_captures:A}"
"$synthesis_fixture/SynthesisVerification.app/Contents/MacOS/Synthesis" | tee "$synthesis_captures/capture.log"
rg -q 'Native captures complete' "$synthesis_captures/capture.log"
rg -q 'BACKGROUND VERIFIED: no visible window or activation' "$synthesis_captures/capture.log"
print "Background native captures: $synthesis_captures"
print "Optional contact sheets: uv run --with pillow python scripts/contact-sheets.py '$synthesis_captures'"
