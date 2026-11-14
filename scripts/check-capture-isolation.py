#!/usr/bin/env python3
"""Exercise fail-closed capture startup without visible windows or desktop input."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

executable = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="synthesis-capture-guard-") as directory:
    env = dict(os.environ, SYNTHESIS_CAPTURE_DIR=directory)
    env.pop("SYNTHESIS_DATABASE_PATH", None)
    result = subprocess.run([executable], env=env, capture_output=True, text=True, timeout=15)
    assert result.returncode != 0 and "fresh isolated database" in result.stderr, result.stderr
    print("PASS: capture refuses a missing isolated database path")
    existing = Path(directory) / "existing.sqlite"
    existing.write_text("preserve this file")
    env["SYNTHESIS_DATABASE_PATH"] = str(existing)
    result = subprocess.run([executable], env=env, capture_output=True, text=True, timeout=15)
    assert result.returncode != 0 and "fresh isolated database" in result.stderr, result.stderr
    assert existing.read_text() == "preserve this file"
    print("PASS: capture refuses and preserves an existing database")
