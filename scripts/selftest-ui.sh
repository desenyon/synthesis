#!/bin/zsh
# Posts real pointer and key events to the app's own window (isolated database) and checks what
# the app did: header hit-testing, card drag, marquee, delete, undo, double-click, companion
# resize. SwiftUI gestures only respond in the key window of the active app, so the runner comes
# to the front for a few seconds and then returns focus. It never moves the system cursor.
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build.sh release
synthesis_fixture="$(mktemp -d /tmp/synthesis-ui.XXXXXX)"
synthesis_output="${1:-$PWD/docs/verification/latest}"
mkdir -p "$synthesis_output"
export SYNTHESIS_DATABASE_PATH="$synthesis_fixture/workspace.sqlite"
export SYNTHESIS_CAPTURE_DIR="${synthesis_output:A}"
export SYNTHESIS_SELFTEST_DIR="${synthesis_output:A}"
dist/Synthesis.app/Contents/MacOS/Synthesis | tee "$synthesis_output/selftest.log"
rg -q 'Interaction self-test passed' "$synthesis_output/selftest.log"
