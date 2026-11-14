#!/usr/bin/env python3
"""Negative startup checks; neither case may open a window or modify a database."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="synthesis-isolation-") as root:
    env = dict(os.environ, SYNTHESIS_CAPTURE_DIR=root)
    env.pop("SYNTHESIS_DATABASE_PATH", None)
    result = subprocess.run([binary], env=env, capture_output=True, timeout=15)
    assert result.returncode != 0 and b"fresh isolated" in result.stderr
    existing = Path(root) / "existing.sqlite"
    existing.write_bytes(b"do not touch")
    env["SYNTHESIS_DATABASE_PATH"] = str(existing)
    result = subprocess.run([binary], env=env, capture_output=True, timeout=15)
    assert result.returncode != 0 and b"fresh isolated" in result.stderr
    assert existing.read_bytes() == b"do not touch"
print("PASS capture refuses absent/occupied database paths before opening a window")
