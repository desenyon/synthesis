#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift format lint --strict --recursive Sources Tests Package.swift
./scripts/test.sh
./scripts/build.sh release
