#!/bin/zsh
# Two separate, nonactivating executions of the built app against a disposable database.
set -euo pipefail
cd "${0:A:h:h}"
python3 - <<'PY'
from pathlib import Path
import os
import subprocess
import tempfile
import uuid

binary = Path('dist/Synthesis.app/Contents/MacOS/Synthesis').resolve()
if not binary.is_file():
    raise SystemExit('Build the app first with ./scripts/check.sh')
with tempfile.TemporaryDirectory(prefix='synthesis-session.', dir=os.environ.get('TMPDIR')) as fixture:
    environment = dict(os.environ, SYNTHESIS_CAPTURE_DIR=fixture,
                       SYNTHESIS_SESSION_AUDIT_TOKEN=str(uuid.uuid4()))
    for phase in ('write', 'read'):
        subprocess.run([str(binary)], check=True,
                       env=dict(environment, SYNTHESIS_SESSION_AUDIT_PHASE=phase))
PY
