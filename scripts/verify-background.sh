#!/bin/zsh
# A bounded verification run: no UI input, application activation, watcher or daemon.
set -euo pipefail
cd "${0:A:h:h}"
export SYNTHESIS_BUILD_JOBS="${SYNTHESIS_BUILD_JOBS:-2}"
synthesis_output="${1:-$PWD/test-results/background}"
mkdir -p "$synthesis_output"
synthesis_output="${synthesis_output:A}"
{
  swift format lint --strict --recursive Sources Tests Package.swift
  nice -n 10 ./scripts/test.sh --jobs "$SYNTHESIS_BUILD_JOBS"
  nice -n 10 ./scripts/verify-ui.sh "$synthesis_output"
  print "Background verification passed. Artifacts: $synthesis_output"
} 2>&1 | tee "$synthesis_output/verification.log"
